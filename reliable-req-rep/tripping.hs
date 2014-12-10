{-
    Round-trip demonstrator.
    Runs as a single process for easier testing.
    The client task signals to main when it's ready.
-}
import System.ZMQ4
import ZHelpers 

import Control.Concurrent
import Control.Monad (forM_)
import Data.ByteString.Char8 (pack, unpack, empty, ByteString(..))

clientTask :: Context -> Socket Req -> IO ()
clientTask ctx pipe =
    withSocket ctx Dealer $ \client -> do
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

main :: IO ()
main = undefined
