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
    , worker :: Socket Dealer
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
    return api { worker = reconnectedWorker
               , liveness = heartbeatLiveness 
               , heartbeat_at = nextHeartbeat
               }

mdwkrInit :: String -> String -> Bool -> IO WorkerAPI
mdwkrInit broker service verbose = do
    ctx <- context
    worker <- socket ctx Dealer -- TODO: mdwkrConnectToBroker creates the socket again!
    let newAPI = WorkerAPI { ctx = ctx
                           , broker = broker
                           , service = service
                           , worker = worker
                           , verbose = verbose
                           , heartbeat_at = 0
                           , liveness = 0
                           , reconnectDelay_ms = 2500
                           , heartbeatDelay_ms = 2500
                           , expect_reply = 0
                           , reply_to = [empty]
                           }
    s_mdwkrConnectToBroker newAPI

mdwkrExchange = undefined

mdwkrSetReconnect = undefined

mdwkrSetHeartbeat = undefined
