-- |
-- Broker prototype of request-reply flow
-- |
module Main where

import System.ZMQ4.Monadic
import Data.Restricted
import ZHelpers

import System.Environment (getArgs)
import System.Random (randomRIO)
import System.IO (hSetEncoding, stdout, utf8)
import Data.ByteString.Char8 (pack, unpack)
import Data.List (null)
import Control.Monad (forever, forM_, when)
import Control.Concurrent (threadDelay)
import Control.Applicative ((<$>))


type SockID = String
type RouterSock z = Socket z Router


nbrClients = 10 :: Int
nbrWorkers = 3 :: Int
workerReady = "\001"

localfe = "1"
localbe = "2"
cloud = "3"


-- Does simple request-reply dialog using a standard synchronous REQ socket
clientTask :: String -> IO ()
clientTask self =
    runZMQ $ do
        client <- socket Req
        connect client ("tcp://localhost:" ++ self ++ localfe)

        forever $ do
            send client [] (pack "HELLO")
            reply <- receive client
            liftIO $ putStrLn $ "Client: " ++ (unpack reply)
            liftIO $ threadDelay $ 1 * 1000 * 1000


-- Plugs into the load balancer using a REQ socket
workerTask :: String -> IO ()
workerTask self =
    runZMQ $ do
        worker <- socket Req
        connect worker ("tcp://localhost:" ++ self ++ localbe)

        send worker [] (pack workerReady)

        forever $ do
            msg <- receive worker
            liftIO $ putStrLn $ "Worker: " ++ (unpack msg)
            send worker [] (pack "OK")


main :: IO ()
main = 
    runZMQ $ do
        liftIO $ hSetEncoding stdout utf8
        args <- liftIO $ getArgs

        if length args < 1
        then liftIO $ putStrLn "Syntax: protoLocalCloudFlow me {you}..."
        else do
            ((self, s_cloudfe), s_cloudbe) <- connectCloud args
            (s_localfe, s_localbe) <- connectLocal self

            liftIO $ putStrLn "Press Enter when all brokers are started" >> getChar

            forM_ [1..nbrWorkers] $ \_ -> do
                async $ liftIO $ workerTask self
            forM_ [1..nbrClients] $ \_ -> do
                async $ liftIO $ clientTask self

            -- We handle the request-reply flow. We're using load-balancing to poll
            -- workers at all times, and clients only when there are one or more
            -- workers available.
            lruQueue s_localbe s_cloudbe s_cloudfe s_localfe args


connectCloud :: [String] -> ZMQ z ((SockID, RouterSock z), RouterSock z)
connectCloud args = do
    let self = args !! 0 ++ cloud
    liftIO $ putStrLn $ "I: Preparing broker at `" ++ self ++ "`"

    s_cloudfe <- socket Router
    setIdentity (restrict $ pack self) s_cloudfe
    bind s_cloudfe ("tcp://*:" ++ self)

    s_cloudbe <- socket Router
    setIdentity (restrict $ pack self) s_cloudbe
    forM_ [1..(length args - 1)] $ \i -> do
        let peer = args !! i ++ cloud
        liftIO $ putStrLn $ "II: Connecting to cloud frontend at " ++ peer
        connect s_cloudbe ("tcp://localhost:" ++ peer)

    return (((init self), s_cloudfe), s_cloudbe) 

connectLocal :: SockID -> ZMQ z (RouterSock z, RouterSock z)
connectLocal self = do
    s_localfe <- socket Router
    bind s_localfe ("tcp://*:" ++ self ++ localfe)
    s_localbe <- socket Router
    bind s_localbe ("tcp://*:" ++ self ++ localbe)

    return (s_localfe, s_localbe)


lruQueue :: RouterSock z -> RouterSock z -> RouterSock z -> RouterSock z -> [SockID] -> ZMQ z ()
lruQueue s_localbe s_cloudbe s_cloudfe s_localfe brokerIDs = 
    loop []
  where loop workers = do
            [eLoc, eCloud] <- poll (getMsecs workers)
                                   [ Sock s_localbe [In] Nothing
                                   , Sock s_cloudbe [In] Nothing ]
            workers' <-
                processBackend workers s_localbe s_cloudbe s_cloudfe s_localfe brokerIDs eLoc eCloud
            if not $ null workers'
            then do
                workers'' <- processFrontend s_localbe s_cloudbe s_cloudfe s_localfe workers' brokerIDs
                loop workers''
            else loop workers'

        getMsecs [] = -1
        getMsecs _ = 1000


processBackend ::
    [SockID] -> RouterSock z -> RouterSock z -> RouterSock z -> RouterSock z -> [SockID] -> [Event] -> [Event] -> ZMQ z ([SockID])
processBackend workers s_localbe s_cloudbe s_cloudfe s_localfe brokerIDs eLoc eCloud = do
    (workers', msg) <- getMessages s_localbe s_cloudbe eLoc eCloud workers
    when (msg /= "") $
        routeMessage s_cloudfe s_localfe msg brokerIDs

    return (workers')

getMessages :: RouterSock z -> RouterSock z -> [Event] -> [Event] -> [SockID] -> ZMQ z ([SockID], String)
getMessages s_localbe s_cloudbe eLoc eCloud workers
    | In `elem` eLoc = do
        frame <- receiveMulti s_localbe
        let frameStr = toStr frame
            id = frameStr !! 0
            msg = frameStr !! 2
            newWorkers = id:workers
        if msg == workerReady
        then return (newWorkers, "")
        else return (newWorkers, msg)

    | In `elem` eCloud = do
        liftIO $ putStrLn "has cloud"
        frame <- receiveMulti s_cloudbe
        let frameStr = toStr frame
            msg = frameStr !! 2
        return (workers, msg)

    | otherwise = return (workers, "")
  where toStr bs = unpack <$> bs

routeMessage :: RouterSock z -> RouterSock z -> String -> [SockID] -> ZMQ z ()
routeMessage s_cloudfe s_localfe msg brokerIDs = do
    let frame = words msg
        info = frame !! 0
        --info = frame !! 1
    forM_ [1..(length brokerIDs - 1)] $ (\i -> do
        when (info /= "" && info == (brokerIDs !! i)) $ do
            liftIO $ putStrLn "sending to brokers"
            send s_cloudfe [] (pack info))
    when (msg /= "") $ do
        send s_localfe [] (pack info)


processFrontend :: RouterSock z -> RouterSock z -> RouterSock z -> RouterSock z -> [SockID] -> [SockID] -> ZMQ z ([SockID]) 
processFrontend _ _ _ _ [] _ = return ([])
processFrontend s_localbe s_cloudbe s_cloudfe s_localfe workers brokerIDs = do
    [eLoc, eCloud] <- poll 0 [ Sock s_localfe [In] Nothing
                             , Sock s_cloudfe [In] Nothing ]

    if In `elem` eCloud
    then do
        msg <- receiveMulti s_cloudfe
        liftIO $ putStrLn $ "received from s_cloudfe " ++ (unwords $ unpack <$> msg)
        send s_localbe [SendMore] (pack $ head workers)
        send s_localbe [SendMore] (pack "")
        send s_localbe [] $ msg !! 0
        processFrontend s_localbe s_cloudbe s_cloudfe s_localfe (tail workers) brokerIDs
    else if In `elem` eLoc 
        then do
            msg <- receive s_localfe
            chance <- liftIO $ randomRIO (0::Int, 5)
            when (chance == (0::Int)) (do
                peerIdx <- liftIO $ randomRIO (1::Int, (length brokerIDs) - 1)
                let peer = brokerIDs !! peerIdx ++ cloud
                send s_cloudbe [SendMore] (pack peer)
                send s_cloudbe [SendMore] (pack "")
                send s_cloudbe [] msg
                )
            processFrontend s_localbe s_cloudbe s_cloudfe s_localfe workers brokerIDs
        else return (workers)
