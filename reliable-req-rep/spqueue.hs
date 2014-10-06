{--
Simple Pirate queue in Haskell
--}
module Main where

import System.ZMQ4.Monadic
import Control.Concurrent (threadDelay)
import Control.Monad (when)
import Data.ByteString.Char8 (pack, unpack)


type SockID = String

workerReady = "\001"

main :: IO ()
main = 
    runZMQ $ do
        frontend <- socket Router
        bind frontend "tcp://*:5555"
        backend <- socket Router
        bind backend "tcp://*:5556"

        pollPeers frontend backend []

pollPeers :: Socket z Router -> Socket z Router -> [SockID] -> ZMQ z ()
pollPeers frontend backend workers = do
    [evtB, evtF] <- poll 0 (getPollList workers)

    when (In `elem` evtB) $ do
        id <- receive backend
        msg <- (receive backend >> receive backend)

        when ((unpack msg) /= workerReady) $ send frontend [] msg

        pollPeers frontend backend ((unpack id):workers)
    
    when (In `elem` evtF) $ do
        msg <- (receive frontend >> receive frontend >> receive frontend)
        let id = head workers
            toSend = unwords $ [id, "", unpack msg]
        send backend [] (pack toSend)
        pollPeers frontend backend (tail workers)
  where getPollList [] = [Sock backend [In] Nothing]
        getPollList _  = [Sock backend [In] Nothing, Sock frontend [In] Nothing]
