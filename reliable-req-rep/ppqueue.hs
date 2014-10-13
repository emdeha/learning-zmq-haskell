{-
Paranoid Pirate Pattern queue in Haskell.
Uses heartbeating to detect crashed or blocked workers.
-}
module Main where

import System.ZMQ4.Monadic
import ZHelpers

import Control.Monad (when, forM_)
import Data.ByteString.Char8 (pack, unpack, empty)
import Data.Time.Clock
import Data.Time.LocalTime
import Data.Fixed


type SockID = String

data Worker = Worker {
                       sockID :: SockID
                     , expiry :: Integer
                     } deriving (Show)

heartbeatLiveness = 3
heartbeatInterval_ms = 1000

pppReady = "\001"
pppHeartbeat = "\002"

main :: IO ()
main = 
    runZMQ $ do
        frontend <- socket Router
        bind frontend "tcp://*:5555"
        backend <- socket Router
        bind backend "tcp://*:5556"

        heartbeat_at <- liftIO $ nextHeartbeatTime_ms heartbeatInterval_ms
        pollPeers frontend backend [] heartbeat_at

createWorker :: SockID -> IO Worker
createWorker id = do
    currTime <- currentTime_ms
    let expiry = currTime + heartbeatInterval_ms * heartbeatLiveness
    return (Worker id expiry)

pollPeers :: Socket z Router -> Socket z Router -> [Worker] -> Integer -> ZMQ z ()
pollPeers frontend backend workers heartbeat_at = do
    let toPoll = getPollList workers
    evts <- poll (fromInteger heartbeatInterval_ms) toPoll

    workers' <- getBackend backend frontend evts workers
    workers'' <- getFrontend frontend backend evts workers'

    newHeartbeatAt <- heartbeat backend workers heartbeat_at

    workersPurged <- purge workers''

    pollPeers frontend backend workersPurged newHeartbeatAt
    
  where getPollList [] = [Sock backend [In] Nothing]
        getPollList _  = [Sock backend [In] Nothing, Sock frontend [In] Nothing]

        getBackend :: Socket z Router -> Socket z Router ->
                      [[Event]] -> [Worker] -> ZMQ z ([Worker])
        getBackend backend frontend evts workers =
            if (In `elem` (evts !! 0))
            then do
                wkrID <- receive backend
                id <- (receive backend >> receive backend)
                msg <- (receive backend >> receive backend)

                if ((length . unpack $ msg) == 1)
                then when (unpack msg /= pppReady && unpack msg /= pppHeartbeat) $ do
                    liftIO $ putStrLn $ "E: Invalid message from worker " ++ unpack msg
                else do
                    send frontend [SendMore] id
                    send frontend [SendMore] empty
                    send frontend [] msg

                newWorker <- liftIO $ createWorker $ unpack wkrID
                return $ workers ++ [newWorker]
            else return workers

        getFrontend :: Socket z Router -> Socket z Router ->
                       [[Event]] -> [Worker] -> ZMQ z ([Worker])
        getFrontend frontend backend evts workers =
            if (length evts > 1 && In `elem` (evts !! 1))
            then do
                id <- receive frontend
                msg <- (receive frontend >> receive frontend)
                
                let wkrID = sockID . head $ workers
                send backend [SendMore] (pack wkrID)
                send backend [SendMore] empty
                send backend [SendMore] id
                send backend [SendMore] empty
                send backend [] msg
                return $ tail workers
            else return workers
        
        heartbeat :: Socket z Router -> [Worker] -> Integer -> ZMQ z Integer
        heartbeat backend workers heartbeat_at = do
            currTime <- liftIO currentTime_ms
            if (currTime >= heartbeat_at) 
            then do
                forM_ workers (\worker -> do
                    send backend [SendMore] (pack $ sockID worker)
                    send backend [SendMore] empty
                    send backend [] (pack pppHeartbeat))
                liftIO $ nextHeartbeatTime_ms heartbeatInterval_ms
            else return heartbeat_at

        purge :: [Worker] -> ZMQ z ([Worker])
        purge workers = do
            currTime <- liftIO currentTime_ms
            return $ filter (\wkr -> expiry wkr < currTime) workers
