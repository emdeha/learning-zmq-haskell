module Main where

import System.ZMQ4.Monadic
import ZHelpers (setRandomIdentity)

import Control.Concurrent (threadDelay, forkIO)
import Control.Monad (replicateM_, unless)
import Data.ByteString.Char8 (unpack, pack)
import Data.Time.Clock (diffUTCTime, getCurrentTime, UTCTime)
import Text.Printf
import System.Random

nbrWorkers :: Int
nbrWorkers = 10

workerThread :: IO ()
workerThread =
    runZMQ $ do
        worker <- socket Req
        setRandomIdentity worker
        connect worker "tcp://localhost:5671"
        work worker

        where 
            work = loop 0 where
                loop val sock = do
                    send sock [] (pack "ready")
                    workload <- receive sock
                    if unpack workload == "Fired!"
                    then liftIO $ printf "Completed: %d tasks\n" (val::Int)
                    else do
                        rand <- liftIO $ getStdRandom (randomR (500::Int, 5000))
                        liftIO $ threadDelay rand
                        loop (val+1) sock

main :: IO ()
main =
    runZMQ $ do
        client <- socket Router
        bind client "tcp://*:5671"

        liftIO $ replicateM_ nbrWorkers (forkIO $ workerThread)
        
        start <- liftIO getCurrentTime
        clientTask client start

        liftIO $ threadDelay $ 1 * 1000 * 1000

clientTask :: Socket z Router -> UTCTime -> ZMQ z ()
clientTask = loop nbrWorkers where
    loop c sock start = unless (c <= 0) $ do
        -- The next message is the least recently used worker.
        ident <- receive sock
        send sock [SendMore] ident

        receive sock -- envelope delimiter
        receive sock -- ready signal from worker

        send sock [SendMore] (pack "") -- delimiter
        now <- liftIO getCurrentTime -- send work unless time is up
        if c /= nbrWorkers || diffUTCTime now start > 5
        then do
            send sock [] (pack "Fired!")
            loop (c-1) sock start
        else do
            send sock [] (pack "Work harder")
            loop c sock start
