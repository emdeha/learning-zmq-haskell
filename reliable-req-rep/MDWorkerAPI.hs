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
    , heartbeatDelay_ms :: Int
    , reconnectDelay_ms :: Int

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

mdwkrExchange = undefined

mdwkrSetReconnect = undefined

mdwkrSetHeartbeat = undefined
