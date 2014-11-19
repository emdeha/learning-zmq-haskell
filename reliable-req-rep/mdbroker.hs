{-
    Majordomo Protocol Broker
-}
module MDBrokerAPI 
    (
    ) where

import System.ZMQ4
import ZHelpers
import MDPDef

import Data.Map.Strict as Map
import Data.ByteString.Char8 (pack, unpack, empty, ByteString(..))

heartbeatLiveness = 1
heartbeatInterval = 2500
heartbeatExpiry = heartbeatInterval * heartbeatLiveness

data Broker = Broker {
      ctx :: Context
    , socket :: Socket Router
    , verbose :: Bool
    , endpoint :: String
    , services :: Map.Map String Service
    , workers :: Map.Map String Worker
    , bWaiting :: [Worker]
    , heartbeatAt :: Integer
    }

data Service = Service {
      sBroker :: Broker
    , name :: String
    , requests :: [ByteString]
    , sWaiting :: [Worker]
    , workersCount :: Int
    }

data Worker = Worker {
      wBroker :: Broker
    , id :: ByteString
    , identityFrame :: [ByteString]
    , service :: Maybe Service
    , expiry :: Integer
    }


-- Broker functions
s_brokerNew = undefined

s_brokerDestroy = undefined

s_brokerBind = undefined

s_brokerWorkerMsg = undefined

s_brokerClientMsg = undefined

s_brokerPurge = undefined


-- Service functions
s_serviceRequire = undefined

s_serviceDestroy = undefined

s_serviceDispatch = undefined


-- Worker functions
s_workerRequire = undefined

s_workerDelete = undefined

s_workerDestroy = undefined

s_workerSend = undefined

s_workerWaiting = undefined
