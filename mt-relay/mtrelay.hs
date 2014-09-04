-- |
-- Multithreaded relay
-- |
module Main where

import System.ZMQ4.Monadic
import Data.ByteString.Char8 (pack, unpack)
import Control.Concurrent (threadDelay)

step1 :: ZMQ z ()
step1 = do
    xmitter <- socket Pair
    connect xmitter "inproc://step2"
    liftIO $ putStrLn "step1" >> threadDelay (1 * 1000 * 1000)
    send xmitter [] (pack "READY")

step2 :: ZMQ z ()
step2 = do
    receiver <- socket Pair
    bind receiver "inproc://step2"
    async step1

    msg <- receive receiver

    xmitter <- socket Pair
    connect xmitter "inproc://step3"
    liftIO $ putStrLn "step2" >> threadDelay (1 * 1000 * 1000)
    send xmitter [] msg

main :: IO ()
main =
    runZMQ $ do
        receiver <- socket Pair
        bind receiver "inproc://step3"
        async step2

        msg <- receive receiver
        liftIO $ putStrLn $ unwords ["Test successful! ", unpack msg]
