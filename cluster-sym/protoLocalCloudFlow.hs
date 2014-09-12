-- |
-- Broker prototype of request-reply flow
-- |
module Main where

import System.ZMQ4.Monadic
import Data.ByteString.Char8 (pack, unpack)
import Control.Monad (forever)


nbrClients = 10 :: Int
nbrWorkers = 3 :: Int
workerReady = "\001"

localfe = "1"
localbe = "2"
cloudfe = "3"
cloudbe = "4"


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
main = putStrLn "SAD"
