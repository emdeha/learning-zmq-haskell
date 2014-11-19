{-
    Majordomo Protocol Broker
-}
module MDBrokerAPI 
    (
    ) where

import System.ZMQ4
import ZHelpers
import MDPDef

import Control.Exception (bracket)
import Control.Monad (forM_, mapM_, when)
import Data.Map.Strict as Map
import Data.ByteString.Char8 (pack, unpack, empty, ByteString(..))

heartbeatLiveness = 1
heartbeatInterval = 2500
heartbeatExpiry = heartbeatInterval * heartbeatLiveness

data Broker = Broker {
      ctx :: Context
    , bSocket :: Socket Router
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


withBroker :: Bool -> (Broker -> IO a) -> IO a
withBroker verbose action = 
    bracket (s_brokerNew verbose)
            (s_brokerDestroy)
            action

-- Broker functions
s_brokerNew :: Bool -> IO Broker
s_brokerNew verbose = do
    ctx <- context
    bSocket <- socket ctx Router
    nextHeartbeat <- nextHeartbeatTime_ms heartbeatInterval
    return Broker { ctx = ctx
                  , bSocket = bSocket
                  , verbose = verbose
                  , services = Map.empty
                  , workers = Map.empty
                  , bWaiting = []
                  , heartbeatAt = nextHeartbeat
                  , endpoint = []
                  }

s_brokerDestroy :: Broker -> IO ()
s_brokerDestroy broker = do
    close $ bSocket broker
    shutdwn $ ctx broker

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


-- Main. Create a new broker and process messages on its socket.
main :: IO ()
main =
    withBroker True $ \broker -> do
        s_brokerBind broker "tcp://*:5555"

        doPoll broker
      where doPoll :: Broker -> IO ()
            doPoll broker = do
                [evts] <- poll (fromInteger heartbeatInterval) [Sock (bSocket broker) [In] Nothing]

                when (In `elem` evts) $ do
                    msg <- receiveMulti $ bSocket broker

                    when (verbose broker) $ do
                        putStrLn "I: received message: "
                        dumpMsg msg

                    let sender = msg !! 0
                        empty = msg !! 1
                        header = msg !! 2
                    case header of
                        head | head == mdpcClient -> s_brokerClientMsg broker sender msg
                             | head == mdpwWorker -> s_brokerWorkerMsg broker sender msg
                             | otherwise          -> do putStrLn "E: Invalid message"
                                                        dumpMsg msg
                
                currTime <- currentTime_ms
                if currTime > heartbeatAt broker
                then do
                    newBroker <- s_brokerPurge
                    forM_ (bWaiting broker) $ \worker -> do
                        s_workerSend worker mdpwHeartbeat Nothing Nothing
                    nextHeartbeat <- nextHeartbeatTime_ms heartbeatInterval
                    doPoll newBroker { heartbeatAt = nextHeartbeat }
                else doPoll broker
