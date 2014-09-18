-- |
-- Broker prototype of request-reply flow
-- |
module Main where

import System.ZMQ4.Monadic
import ZHelpers

import System.Environment (getArgs)
import System.Random (randomRIO)
import Data.ByteString.Char8 (pack, unpack)
import Control.Monad (forever, forM_, when)
import Control.Concurrent (threadDelay)


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
            send worker [SendMore] msg
            send worker [SendMore] (pack "")
            send worker [] (pack "OK")


main :: IO ()
main = 
    runZMQ $ do
        args <- liftIO $ getArgs

        if length args < 1
        then liftIO $ putStrLn "Syntax: protoLocalCloudFlow me {you}..."
        else do
            ((self, s_cloudfe), s_cloudbe) <- connectCloud args
            (s_localfe, s_localbe) <- connectLocal self

            --liftIO $ putStrLn "Press Enter when all brokers are started" >> getChar

            forM_ [1..nbrWorkers] $ \_ -> do
                async $ liftIO $ workerTask self
            forM_ [1..nbrClients] $ \_ -> do
                async $ liftIO $ clientTask self

            liftIO $ putStrLn "Started workers"

            -- We handle the request-reply flow. We're using load-balancing to poll
            -- workers at all times, and clients only when there are one or more
            -- workers available.
            pollBackends s_localbe s_cloudbe s_cloudfe s_localfe [] args


connectCloud :: [String] -> ZMQ z ((SockID, RouterSock z), RouterSock z)
connectCloud args = do
    let self = args !! 0 ++ cloud
    liftIO $ putStrLn $ "I: Preparing broker at " ++ self

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


pollBackends :: RouterSock z -> RouterSock z -> RouterSock z -> RouterSock z -> [SockID] -> [SockID] -> ZMQ z ()
pollBackends s_localbe s_cloudbe s_cloudfe s_localfe workers brokerIDs = do
    [eLoc, eCloud] <- poll (getMsecs workers)
                           [ Sock s_localbe [In] Nothing
                           , Sock s_cloudbe [In] Nothing ]
    
    (newWorkers, msg) <- getMessages s_localbe s_cloudbe eLoc eCloud workers
    when (msg /= "") $ do
        --liftIO $ putStrLn $ msg
        routeMessage s_cloudfe s_localfe msg brokerIDs

    newWorkers' <- pollFrontends s_localbe s_cloudbe s_cloudfe s_localfe newWorkers brokerIDs

    pollBackends s_localbe s_cloudbe s_cloudfe s_localfe newWorkers' brokerIDs

  where 
        getMsecs [] = -1
        getMsecs _ = 1000


getMessages :: RouterSock z -> RouterSock z -> [Event] -> [Event] -> [SockID] -> ZMQ z ([SockID], String)
getMessages s_localbe s_cloudbe eLoc eCloud workers
    | In `elem` eLoc = do
        id <- receive s_localbe
        empty <- receive s_localbe
        msg <- receive s_localbe
        let newWorkers = (unpack id):workers
        if (unpack msg) == workerReady
        then return (newWorkers, "")
        else return (newWorkers, (unpack msg))

    | In `elem` eCloud = do
        id <- receive s_cloudbe
        msg <- receive s_cloudbe
        return (workers, (unpack msg))

    | otherwise = return (workers, "")

routeMessage :: RouterSock z -> RouterSock z -> String -> [SockID] -> ZMQ z ()
routeMessage s_cloudfe s_localfe msg brokerIDs = do
    forM_ [1..(length brokerIDs - 1)] $ (\i -> do
        liftIO $ putStrLn $ "broker id: " ++ (brokerIDs !! i) ++ " msg: " ++ msg
        when (msg == (brokerIDs !! i)) $
            send s_cloudfe [] (pack msg))
    when (msg /= "") $ send s_localfe [] (pack msg)

pollFrontends :: RouterSock z -> RouterSock z -> RouterSock z -> RouterSock z -> [SockID] -> [SockID] -> ZMQ z ([SockID]) 
pollFrontends _ _ _ _ [] _ = return ([])
pollFrontends s_localbe s_cloudbe s_cloudfe s_localfe workers brokerIDs = do
    [eLoc, eCloud] <- poll 0 [ Sock s_localfe [In] Nothing
                             , Sock s_cloudfe [In] Nothing ]

    liftIO $ putStrLn $ "polling frontends: " ++ (show $ length workers)

    if In `elem` eCloud
    then do
        msg <- receive s_cloudfe
        send s_localbe [SendMore] (pack $ head workers)
        send s_localbe [SendMore] (pack "")
        send s_localbe [] msg 
        pollFrontends s_localbe s_cloudbe s_cloudfe s_localfe (tail workers) brokerIDs
    else if In `elem` eLoc 
        then do
            msg <- receive s_localfe
            chance <- liftIO $ randomRIO (0::Int, 5)
            when (chance == (0::Int)) $ (do
                peerIdx <- liftIO $ randomRIO (1::Int, (length brokerIDs) - 1)
                let peer = brokerIDs !! peerIdx ++ cloud
                send s_cloudbe [SendMore] (pack peer)
                send s_cloudbe [SendMore] (pack "")
                send s_cloudbe [] msg)
            pollFrontends s_localbe s_cloudbe s_cloudfe s_localfe workers brokerIDs
        else return (workers)
