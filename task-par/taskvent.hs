-- |
-- Task ventilator
-- Binds PUSH socket to tcp://*:5557
-- Sends batch of tasks to workers via that socket
-- |
module Main where

import System.ZMQ4.Monadic (runZMQ, socket, bind, connect, send, Push(..), liftIO)
import System.Random (randomRIO)
import System.IO (hFlush, stdout)
import Control.Monad (replicateM)
import Control.Applicative ((<$>))
import Control.Concurrent (threadDelay)
import Data.ByteString.Char8 (pack)

main :: IO ()
main = 
    runZMQ $ do
        sender <- socket Push
        bind sender "tcp://*:5557"

        sink <- socket Push
        connect sink "tcp://localhost:5558"

        liftIO $ putStrLn "Press Enter when the workers are ready: " >> hFlush stdout
        liftIO $ getLine >> putStrLn "Sending tasks to workers..."

        -- The first message "0" signals the start of a batch
        send sink [] (pack "0")

        -- Send 100 tasks, calculate total workload
        workload <- sum <$> replicateM 100 (do
            workload' <- liftIO (randomRIO (1, 100) :: IO Int)
            send sender [] (pack $ show workload')
            return workload')

        liftIO $ putStrLn $ unwords ["Total expected cost: ", show workload, "ms"]
        liftIO $ threadDelay $ 1 * 1000 * 1000

        liftIO $ getLine
