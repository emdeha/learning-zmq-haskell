{-
    Majordomo Protocol Broker
-}
module MDBrokerAPI 
    (
    ) where

import System.ZMQ4
import ZHelpers
import MDPDef

import Control.Monad.Trans.State
import Control.Monad.IO.Class (liftIO)
import Control.Exception (bracket)
import Control.Monad (forever, forM_, mapM_, foldM, when)
import Data.ByteString.Char8 (pack, unpack, empty, ByteString(..))
import qualified Data.Map.Strict as M
import qualified Data.List as L (partition)

heartbeatLiveness = 1
heartbeatInterval = 2500
heartbeatExpiry = heartbeatInterval * heartbeatLiveness

data Broker = Broker {
      ctx :: Context
    , bSocket :: Socket Router
    , verbose :: Bool
    , endpoint :: String
    , services :: M.Map String Service
    , workers :: M.Map String Worker
    , bWaiting :: [Worker]
    , heartbeatAt :: Integer
    }

data Service = Service {
      name :: String
    , requests :: [ByteString]
    , sWaiting :: [Worker]
    , workersCount :: Int
    }

data Worker = Worker {
      wId :: ByteString
    , identityFrame :: [ByteString]
    , expiry :: Integer
    } deriving (Eq)


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
                  , services = M.empty
                  , workers = M.empty
                  , bWaiting = []
                  , heartbeatAt = nextHeartbeat
                  , endpoint = []
                  }

s_brokerDestroy :: Broker -> IO ()
s_brokerDestroy broker = do
    close $ bSocket broker
    shutdown $ ctx broker

s_brokerBind :: Broker -> String -> IO ()
s_brokerBind broker endpoint = do
    bind (bSocket broker) endpoint
    putStrLn $ "I: MDP broker/0.2.0 is active at " ++ endpoint

-- Processes READY, REPLY, HEARTBEAT, or DISCONNECT worker message
s_brokerWorkerMsg = undefined

s_brokerClientMsg = undefined

s_brokerPurge :: Broker -> IO Broker
s_brokerPurge broker = do
    currTime <- currentTime_ms
    let (toPurge, rest) = L.partition (\worker -> currTime > expiry worker)
                                      (bWaiting broker)
        leftInMap       = M.filterWithKey (isPurgedKey toPurge) (workers broker)
        purgedServices  = purgeWorkersFromServices toPurge (services broker)
    mapM_ (flip s_workerDelete False) toPurge
    return broker { bWaiting = rest 
                  , workers = leftInMap 
                  }
  where isPurgedKey toPurge key _ = 
            key `notElem` (map (unpack . wId) toPurge)

        purgeWorkersFromServices workers services = 
            M.map purge services
          where purge service =
                    let (toPurge, rest) = L.partition (\worker -> worker `elem` workers)
                                                      (sWaiting service)
                    in  service { sWaiting = rest
                                , workersCount = (workersCount service) - (length toPurge)
                                }
           


-- Service functions
s_serviceRequire = undefined

s_serviceDestroy = undefined

s_serviceDispatch = undefined


-- Worker functions
s_workerRequire = undefined

s_workerDelete :: Worker -> Bool -> IO () 
s_workerDelete worker isDisconnect =
    when isDisconnect $ do
        s_workerSend worker mdpwDisconnect Nothing Nothing

s_workerSend = undefined

s_workerWaiting = undefined


-- Main. Create a new broker and process messages on its socket.
main :: IO ()
main = undefined
{-
    withBroker True $ \broker -> do
        s_brokerBind broker "tcp://*:5555"
        evalState doPoll broker-- (foreverS doPoll) broker
      where --doPoll :: State Broker (IO ())
            doPoll =
                forever $ do
                    broker <- get
                    [evts] <- poll (fromInteger heartbeatInterval) 
                                   [Sock (bSocket broker) [In] Nothing]

                    when (In `elem` evts) $ do
                        msg <- liftIO $ receiveMulti $ bSocket broker

                        when (verbose broker) $ do
                            liftIO $ putStrLn "I: received message: " >> dumpMsg msg

                        let sender = msg !! 0
                            empty = msg !! 1
                            header = msg !! 2
                            msg' = drop 3 msg
                        case header of
                            head | head == mdpcClient -> s_brokerClientMsg sender msg'
                                 | head == mdpwWorker -> s_brokerWorkerMsg sender msg'
                                 | otherwise          -> do liftIO $ putStrLn "E: Invalid message"
                                                            liftIO $ dumpMsg msg'
     
                    currTime <- liftIO $ currentTime_ms
                    when (currTime > heartbeatAt broker) $ do
                        s_brokerPurge
                        forM_ (bWaiting broker) $ \worker -> do
                            s_workerSend worker mdpwHeartbeat Nothing Nothing
                        nextHeartbeat <- liftIO $ nextHeartbeatTime_ms heartbeatInterval
                        newBroker <- get
                        put newBroker { heartbeatAt = nextHeartbeat }

foreverS :: State s a -> State s a
foreverS body =
    do modify (execState body)
       foreverS body
  where execState :: State s a -> s -> s
        execState mv init_st = snd (runState mv init_st)
-}
