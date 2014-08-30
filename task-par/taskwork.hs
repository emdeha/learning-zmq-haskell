-- |
-- Task worker
-- Connects PULL socket to tcp://localhost:5557
-- Collects workloads from ventilator via that socket
-- Connects PUSH socket to tcp://localhost:5558
-- Sends results to sink via that socket
-- |
module Main where

import System.ZMQ4.Monadic
import System.IO (hSetBuffering, stdout, BufferMode(..))
import Control.Monad (forever)
import Control.Applicative ((<$>))
import Control.Concurrent (threadDelay)
import Data.ByteString.Char8 (unpack, empty)

main :: IO ()
main =
    runZMQ $ do
        -- connect to the ventilator
        receiver <- socket Pull
        connect receiver "tcp://localhost:5557"

        -- connect to the sink
        sender <- socket Push
        connect sender "tcp://localhost:5558"

        liftIO $ hSetBuffering stdout NoBuffering
        forever $ do
            msg <- unpack <$> receive receiver
            -- progress indicator
            liftIO $ putStr $ msg ++ "."

            -- "work"
            liftIO $ threadDelay (read msg * 1000)

            -- send results to sink
            send sender [] empty
