-- | 
-- Reading from multiple sockets
-- This version uses a simple recv loop
-- |
module Main where

import System.ZMQ4.Monadic
import Control.Monad (forever, mplus)
import Control.Error (left)
import Control.Concurrent (threadDelay)
import Data.ByteString.Char8 (pack, unpack)

main :: IO ()
main = 
    runZMQ $ do
        receiver <- socket Pull
        connect receiver "tcp://localhost:5557"

        subscriber <- socket Sub
        connect subscriber "tcp://localhost:5556"
        subscribe subscriber (pack "1001")

        liftIO $ putStrLn "Initialized..."

        forever $ do
            task <- receive receiver
            info <- receive subscriber
            liftIO $ putStrLn $ "Received: " ++ (unpack task `mplus` unpack info)
            liftIO $ threadDelay (1 * 1000)
