-- |
-- Simple multipart message subscriber in Haskell
-- |
module Main where

import System.ZMQ4.Monadic
import Control.Monad (forever)
import Control.Concurrent (threadDelay)
import Data.ByteString.Char8 (pack, unpack)

main :: IO ()
main =
    runZMQ $ do
        liftIO $ putStrLn "Establishing client..."
        subSocket <- socket Sub
        connect subSocket "tcp://localhost:5555"
        subscribe subSocket (pack "Hello...")

        forever $ do
            msg <- receive subSocket
            liftIO $ putStrLn $ "Received: " ++ (unpack msg)
