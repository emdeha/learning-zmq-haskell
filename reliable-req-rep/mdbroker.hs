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
import Data.Maybe (catMaybes, maybeToList, fromJust, isJust)
import qualified Data.ByteString.Char8 as B
import qualified Data.Map.Strict as M
import qualified Data.List as L (partition, init, length, span)
import qualified Data.List.NonEmpty as N

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
    , requests :: [B.ByteString]
    , sWaiting :: [Worker]
    , workersCount :: Int
    }

data Worker = Worker {
      wId :: B.ByteString
    , identityFrame :: [B.ByteString]
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

-- Process a request coming from a client.
s_brokerClientMsg :: Broker -> B.ByteString -> [B.ByteString] -> IO (Broker, Service)
s_brokerClientMsg broker senderFrame msg = do
    when (L.length msg < 2) $ do
        error "E: Too little frames in message"

    let (serviceFrame, msg') = pop msg
        (newBroker, service) = s_serviceRequire broker serviceFrame
        msg'' = wrap msg' senderFrame

    if (B.pack "mmi.") `B.isPrefixOf` serviceFrame
    then do
        let returnCode = B.pack $ checkService service serviceFrame msg''
            returnMsg = L.init msg'' ++ [returnCode]
            (client, msg''') = pop msg''
            finalMsg = wrap (mdpcClient : serviceFrame : msg''') client
        sendMulti (bSocket newBroker) (N.fromList finalMsg)
        return (newBroker, service)
    else s_serviceDispatch newBroker service (Just msg'')

  where checkService service serviceFrame msg =
            if serviceFrame == B.pack "mmi.service"
            then let name = last msg
                     namedService = M.lookup (B.unpack name) (services broker)
                 in  if isJust namedService && workersCount (fromJust namedService) > 0
                     then "200"
                     else "404"
            else "501"

    
-- TODO: This should stop as soon as it finds the first non-expired worker
s_brokerPurge :: Broker -> IO Broker
s_brokerPurge broker = do
    currTime <- currentTime_ms
    let (toPurge, rest) = L.span (\worker -> currTime > expiry worker)
                                 (bWaiting broker)
        leftInMap       = M.filterWithKey (isNotPurgedKey toPurge) (workers broker)
        purgedServices  = purgeWorkersFromServices toPurge (services broker)
    mapM_ (s_workerSendDisconnect broker) toPurge
    return broker { bWaiting = rest 
                  , workers = leftInMap 
                  , services = purgedServices
                  }
  where isNotPurgedKey toPurge key _ = 
            key `notElem` (map (B.unpack . wId) toPurge)

        purgeWorkersFromServices workers = M.map purge
          where purge service =
                    let (toPurge, rest) = L.partition (\worker -> worker `elem` workers)
                                                      (sWaiting service)
                    in  service { sWaiting = rest
                                , workersCount = (workersCount service) - (length toPurge)
                                }
           


-- Service functions

-- Inserts a new service in the broker's services if that service didn't exist.
s_serviceRequire :: Broker -> B.ByteString -> (Broker, Service)
s_serviceRequire broker serviceFrame = do
    let foundService = M.lookup (B.unpack serviceFrame) (services broker)
    case foundService of
        Nothing -> createNewService
        Just fs -> (broker, fs)
  where createNewService =
            let newService = Service { name = B.unpack serviceFrame -- TODO: base16 encode this
                                     , requests = []
                                     , sWaiting = []
                                     , workersCount = 0
                                     }
            in (broker { services = M.insert (name newService) newService (services broker) }
               , newService)

s_serviceDispatch :: Broker -> Service -> Maybe [B.ByteString] -> IO (Broker, Service)
s_serviceDispatch broker service msg = do
    purgedBroker <- s_brokerPurge broker
    let workersWithMessages = zip (sWaiting service) (requests service)
        wkrsToRemain = filter (\wkr -> wkr `notElem` (map fst workersWithMessages)) (bWaiting broker)
        rqsToRemain = filter (\rq -> rq `notElem` (map snd workersWithMessages)) (requests service)
    forM_ workersWithMessages $ \wkrMsg -> do
        s_workerSend broker (fst wkrMsg) mdpwRequest Nothing (Just $ [snd wkrMsg])
    return ( purgedBroker { bWaiting = wkrsToRemain }
           , service { requests = rqsToRemain })
    

-- Worker functions

-- Inserts a new worker in the broker's workers.
s_workerRequire :: Broker -> B.ByteString -> Broker
s_workerRequire broker identity = do
    if M.member (B.unpack identity) (workers broker)
    then broker
    else createWorker
  where createWorker =
            let newWorker = Worker { wId = identity -- TODO: base16 encode this
                                   , identityFrame = [identity]
                                   , expiry = 0 -- The caller should modify it.
                                   }
            in  broker { workers = M.insert (B.unpack $ wId newWorker) newWorker (workers broker) }

s_workerSendDisconnect :: Broker -> Worker -> IO () 
s_workerSendDisconnect broker worker =
    s_workerSend broker worker mdpwDisconnect Nothing Nothing

s_workerSend :: Broker -> Worker -> B.ByteString -> Maybe B.ByteString -> Maybe [B.ByteString] -> IO ()
s_workerSend broker worker cmd option msg = do
    let msgOpts = option : Just cmd : [Just mdpwWorker]
        msgFinal = wId worker : (concat . maybeToList $ msg) ++ (catMaybes msgOpts)
    when (verbose broker) $ do
        putStrLn $ "I: sending " ++ (B.unpack $ mdpsCommands !! mdpGetIdx (B.unpack cmd)) ++ " to worker"
        dumpMsg msgFinal
    sendMulti (bSocket broker) (N.fromList msgFinal)
  where getMsg (Just msg) = msg
        getMsg Nothing    = [B.empty]

s_workerWaiting :: Broker -> Service -> Worker -> IO (Broker, Service)
s_workerWaiting broker wService worker = do
    currTime <- currentTime_ms
    let newWorker = worker { expiry = currTime + heartbeatExpiry }
        newService = wService { sWaiting = newWorker : sWaiting wService }
        newBroker = broker { bWaiting = newWorker : bWaiting broker }
    s_serviceDispatch newBroker newService Nothing


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
