-- | Task sink
-- Binds PULL socket to tcp://localhost:5558
-- Collects results from workers via the socket
-- |
module Main where

import System.ZMQ4.Monadic
import System.IO (hSetBuffering, stdout, BufferMode(..))
import Control.Monad (forM_)
import Data.Time.Clock (getCurrentTime, diffUTCTime)

main :: IO ()
main = 
    runZMQ $ do
        receiver <- socket Pull
        bind receiver "tcp://*:5558"
        
        -- Wait for "0" - start of batch
        receive receiver

        startTime <- liftIO getCurrentTime
        liftIO $ hSetBuffering stdout NoBuffering

        -- Process 100 results
        forM_ [1..100] $ \i -> do
            receive receiver
            liftIO $ putStr $ if i `mod` 10 == 0 then ":" else "."

        endTime <- liftIO getCurrentTime
        let elapsedTime = diffUTCTime endTime startTime
            elapsedMsec = elapsedTime * 1000
        liftIO $ putStrLn $ unwords ["Total elapsed time: ", show elapsedMsec, "ms"]
