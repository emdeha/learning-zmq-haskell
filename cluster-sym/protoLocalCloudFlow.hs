-- |
-- Broker prototype of request-reply flow
-- |
module Main where

import System.ZMQ4.Monadic
import System.Environment (getArgs)
import Data.ByteString.Char8 (pack, unpack)
import Control.Monad (forever, forM_, when)


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


-- Plugs into the load balancer using a REQ socket
workerTask :: String -> IO ()
workerTask self =
    runZMQ $ do
        worker <- socket Req
        connect worker ("tcp://localhost:" ++ self ++ localbe)

        send worker [SendMore] (pack workerReady)

        forever $ do
            msg <- receive worker
            liftIO $ putStrLn $ "Worker: " ++ (unpack msg)
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

            liftIO $ putStrLn "Press Enter when all brokers are started" >> getChar

            forM_ [1..nbrWorkers] $ \_ -> do
                async $ liftIO $ workerTask self
            forM_ [1..nbrClients] $ \_ -> do
                async $ liftIO $ clientTask self

            -- We handle the request-reply flow. We're using load-balancing to poll
            -- workers at all times, and clients only when there are one or more
            -- workers available.
            pollBackends s_localbe s_cloudbe s_cloudfe s_localfe []


connectCloud :: [String] -> ZMQ z ((SockID, RouterSock z), RouterSock z)
connectCloud args = do
    let self = args !! 0
    liftIO $ putStrLn $ "I: Preparing broker at " ++ self

    s_cloudfe <- socket Router
    setIdentity (restrict $ pack self) s_cloudfe
    bind s_cloudfe ("tcp://*:" ++ self ++ cloud)

    s_cloudbe <- socket Router
    setIdentity (restrict $ pack self) s_cloudbe
    forM_ [1..(length args - 1)] $ \i -> do
        let peer = args !! i
        liftIO $ putStrLn $ "II: Connecting to cloud frontend at " ++ peer
        connect s_cloudbe ("tcp://localhost:" ++ peer ++ cloud)

    return ((self, s_cloudfe), s_cloudbe) 

connectLocal :: SockID -> ZMQ z (RouterSock z, RouterSock z)
connectLocal self = do
    s_localfe <- socket Router
    bind s_localfe ("tcp://*:" ++ self ++ localfe)
    s_localbe <- socket Router
    bind s_localbe ("tcp://*:" ++ self ++ localbe)

    return (s_localfe, s_localbe)


pollBackends :: RouterSock z -> RouterSock z -> RouterSock z -> RouterSock z -> [SockID] -> ZMQ z ()
pollBackends s_localbe s_cloudbe s_cloudfe s_localfe workers = do
    [eLoc, eCloud] <- poll (getMsecs workers)
                           [ Sock s_localbe [In] Nothing
                           , Sock s_cloudbe [In] Nothing ]

    (newWorkers, msg) <- getMessages s_localbe s_cloudbe eLoc eCloud workers
    liftIO $ putStrLn $ "Message: " ++ msg

    pollBackends s_localbe s_cloudbe s_cloudfe s_localfe newWorkers

  where 
        getMsecs [] = -1
        getMsecs _ = 1000


getMessages :: RouterSock z -> RouterSock z -> [Event] -> [Event] -> [SockID] -> ZMQ z ([SockID], String)
getMessages s_localbe s_cloudbe eLoc eCloud workers
    | In `elem` eLoc = do
        id <- receive s_localbe
        msg <- receive s_localbe
        let newWorkers = (unpack id):workers
        if (unpack msg) == workerReady
        then return (newWorkers, "")
        else return (newWorkers, (unpack msg))

    | In `elem` eCloud = do
        id <- receive s_cloudbe
        msg <- receive s_cloudbe
        return (workers, (unpack msg))
