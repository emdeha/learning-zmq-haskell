-- |
-- Simple client in Haskell
-- Gets ID assigned by the server
-- Sends request
-- Received response
-- |
module Main where

import System.ZMQ4.Monadic
import Control.Monad (forever)
import Data.ByteString.Char8 (pack, unpack)

sendInput :: (Sender b) => Socket z b -> String -> ZMQ z ()
sendInput sender id = do
    input <- liftIO $ getLine
    send sender [] (pack $ id ++ ": " ++ input)
    --send sender [] (pack "Hello")

main :: IO ()
main =
    runZMQ $ do
        liftIO $ putStrLn "Connecting to Hello World server..."
        reqSocket <- socket Req
        connect reqSocket "tcp://localhost:5555"

        liftIO $ putStrLn "Getting ID"
        send reqSocket [] (pack $ "id")
        id <- receive reqSocket
        liftIO $ putStrLn $ unwords ["ID: ", unpack id]

        forever $ do
            sendInput reqSocket (unpack id)
            reply <- receive reqSocket
            liftIO $ putStrLn $ unwords ["server: ", unpack reply]
