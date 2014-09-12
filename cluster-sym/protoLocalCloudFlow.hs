-- |
-- Broker prototype of request-reply flow
-- |
module Main where

import System.ZMQ4.Monadic
import System.Environment (getArgs)
import Data.ByteString.Char8 (pack, unpack)
import Control.Monad (forever, forM_)


type SockID = String


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

            return ()

connectCloud :: [String] -> ZMQ z ((SockID, Socket z Router), Socket z Router)
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

connectLocal :: SockID -> ZMQ z (Socket z Router, Socket z Router)
connectLocal self = do
    s_localfe <- socket Router
    bind s_localfe ("tcp://*:" ++ self ++ localfe)
    s_localbe <- socket Router
    bind s_localbe ("tcp://*:" ++ self ++ localbe)

    return (s_localfe, s_localbe)
