{-
Paranoid Pirate worker in Haskell.
Uses heartbeating to detect crashed queue.
-}
module Main where

import System.ZMQ4.Monadic

import Data.ByteString.Char8 (pack, unpack, empty)


heartbeatLiveness = 3
heartbeatInterval_ms = 1000
reconnectIntervalInit = 1000
reconnectIntervalMax = 32000

pppReady = pack "\001"
pppHeartbeat = pack "\002"


createWorkerSocket :: ZMQ z (Socket z Dealer)
createWorkerSocket = do
    worker <- socket Dealer
    connect worker "tcp://localhost:5556"
    
    liftIO $ putStrLn "I: worker ready\n"
    send worker [] pppReady

main :: IO ()
main = 
    runZMQ $ do
        worker <- createWorkerSocket
