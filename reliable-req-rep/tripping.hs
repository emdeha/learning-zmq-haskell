{-
    Round-trip demonstrator.
    Runs as a single process for easier testing.
    The client task signals to main when it's ready.
-}
import System.ZMQ4
import ZHelpers 

import Control.Concurrent
import Control.Monad (forM_, forever)
import Data.ByteString.Char8 (pack)


clientTask :: Context -> Socket Req -> IO ()
clientTask ctx pipe =
    withSocket ctx Dealer $ \client -> do
        connect client "tcp://localhost:5555"
        putStrLn "Setting up test..."
        threadDelay $ 100 * 1000

        putStrLn "Synchronous round-trip test..."
        start <- currentTime_ms
        forM_ [0..10000] $ \_ -> do
            send client [] (pack "hello")
            receive client
        elapsed_ms <- timeElapsed_ms start
        putStrLn $ " " ++ (show $ (1000 * 10000) / (fromInteger elapsed_ms)) ++ " calls/second"

        putStrLn "Asynchronous round-trip test..."
        start <- currentTime_ms
        forM_ [0..10000] $ \_ -> do
            send client [] (pack "hello")
        forM_ [0..10000] $ \_ -> do
            receive client
        elapsed_ms <- timeElapsed_ms start
        putStrLn $ " " ++ (show $ (1000 * 10000) / (fromInteger elapsed_ms)) ++ " calls/second"

        send pipe [] (pack "done")

worker_task :: IO ()
worker_task = 
    withContext $ \ctx -> do
        withSocket ctx Dealer $ \worker -> do
            connect worker "tcp://localhost:5556"

            forever $ do
                msg <- receive worker
                send worker [] msg

main :: IO ()
main = undefined
