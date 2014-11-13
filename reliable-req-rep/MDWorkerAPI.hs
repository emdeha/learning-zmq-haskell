{-
    Majordomo Worker API
-}
module MDWorkerAPI
    (   withMDWorker
    ,   mdwkrExchange
    ,   mdwkrSetReconnect
    ,   mdwkrSetHeartbeat
    ) where


import System.ZMQ4
import ZHelpers
import MDPDef

import Control.Exception (bracket)
import Control.Monad.State
import Data.ByteString.Char8 (pack, unpack, empty, ByteString(..))
import qualified Data.List.NonEmpty as N
import Data.Maybe


data WorkerAPI = WorkerAPI {
      ctx :: Context
    , broker :: String
    , service :: String
    , worker :: Socket Req
    , verbose :: Bool

    -- Heartbeats
    , heartbeat_at :: Integer
    , liveness :: Int
    , heartbeatDelay_ms :: Integer
    , reconnectDelay_ms :: Integer

    , expect_reply :: Int
    , reply_to :: [ByteString]
    }

heartbeatLiveness :: Int
heartbeatLiveness = 3


withMDWorker = undefined

s_mdwkrSendToBroker :: WorkerAPI -> ByteString -> Maybe ByteString -> Maybe [ByteString] -> IO ()
s_mdwkrSendToBroker api command option msg = do
    let args = [option, Just command, Just mdpwWorker, Just empty]
        msg' = fromMaybe [] msg
        wrappedMessage = msg' ++ catMaybes args
    when (verbose api) $ do
        let strCmd = mdpsCommands !! (read . unpack $ command)
        putStrLn $ "I: Sending " ++ unpack strCmd ++ " to broker"
        mapM_ (putStrLn . unpack) wrappedMessage

    sendMulti (worker api) (N.fromList wrappedMessage)

s_mdwkrConnectToBroker :: WorkerAPI -> IO (WorkerAPI)
s_mdwkrConnectToBroker api = do
    close $ worker api
    reconnectedWorker <- socket (ctx api) Dealer 
    connect reconnectedWorker (broker api)
    when (verbose api) $ do
        putStrLn $ "I: connecting to broker at " ++ (broker api)
    s_mdwkrSendToBroker api mdpwReady (Just . pack $ service api) Nothing

    nextHeartbeat <- nextHeartbeatTime_ms $ heartbeatDelay_ms api
    return api { 
                 liveness = heartbeatLiveness, 
                 heartbeat_at = nextHeartbeat
               }

mdwkrExchange = undefined

mdwkrSetReconnect = undefined

mdwkrSetHeartbeat = undefined
