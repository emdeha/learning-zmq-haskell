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

import Control.Exception (bracket)
import Data.ByteString.Char8 (pack, unpack, empty, ByteString(..))
import qualified Data.List.NonEmpty as N


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

withMDWorker = undefined

mdwkrExchange = undefined

mdwkrSetReconnect = undefined

mdwkrSetHeartbeat = undefined
