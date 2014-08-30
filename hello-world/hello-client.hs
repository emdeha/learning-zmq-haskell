-- |
-- Simple client in Haskell
-- Gets ID assigned by the server
-- Sends request
-- Received response
-- |
module Main where

import System.ZMQ4.Monadic
import Control.Monad (forM_)
import Data.ByteString.Char8 (pack, unpack)

main :: IO ()
main =
    runZMQ $ do
        liftIO $ putStrLn "Connecting to Hello World server..."
        reqSocket <- socket Req
        connect reqSocket "tcp://localhost:5555"

        liftIO $ putStrLn "Getting ID"
        send reqSocket [] (pack $ "id")
        id <- receive reqSocket

        forM_ [1..10] $ \i -> do
            liftIO $ putStrLn $ unwords ["Sending request", show i]
            send reqSocket [] (pack $ "Hello " ++ (show i) ++ " | ID: " ++ (unpack id))
            reply <- receive reqSocket
            liftIO $ putStrLn $ unwords ["Received reply:", unpack reply]
