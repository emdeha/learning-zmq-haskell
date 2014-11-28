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
import qualified Data.List as L
import qualified Data.List.NonEmpty as N

heartbeatLiveness = 1
heartbeatInterval = 2500
heartbeatExpiry = heartbeatInterval * heartbeatLiveness

data Broker = Broker {
      ctx :: Context
    , bSocket :: Socket Router
    , verbose :: Bool
    , endpoint :: String
    , services :: M.Map B.ByteString Service
    , workers :: M.Map B.ByteString Worker
    , bWaiting :: [Worker]
    , heartbeatAt :: Integer
    }

data Service = Service {
      name :: B.ByteString
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
s_brokerWorkerMsg :: Broker -> Frame -> Message -> IO Broker
s_brokerWorkerMsg broker senderFrame msg = do
    when (L.length msg < 1) $ do
        error "E: Too little frames in message for worker"

    let (cmdFrame, msg') = pop msg
        id_string = senderFrame -- TODO: base16 encode this
        isWorkerReady = M.member id_string (workers broker)
        (worker, newBroker) = s_workerRequire broker senderFrame

    case cmdFrame of
        cmd | cmd == mdpwReady -> 
                -- Not first cmd in session or reserved service frame.
                if isWorkerReady || (B.pack "mmi.") `B.isPrefixOf` senderFrame
                then do
                    s_workerSendDisconnect broker worker
                    return $ s_brokerDeleteWorker broker worker
                else do
                    let (serviceFrame, _) = pop msg'
                        (service, newBroker) = s_serviceRequire broker serviceFrame
                        newService = service { workersCount = workersCount service + 1 }
                    (newBroker', newService') <- s_workerWaiting newBroker newService worker
                    return newBroker' { services = M.insert (name newService') newService' (services newBroker') }
            | cmd == mdpwReply ->
                  if isWorkerReady 
                  then do
                      let (client, msg'') = pop msg'
                          wkrService = s_brokerGetServiceFor worker newBroker
                          finalMsg = wrap (mdpcClient : name wkrService : msg'') client
                      sendMulti (bSocket newBroker) (N.fromList finalMsg)
                      (newBroker', newService') <- s_workerWaiting newBroker wkrService worker
                      return newBroker' { services = M.insert (name newService') newService'  (services newBroker') }
                  else do
                      s_workerSendDisconnect broker worker 
                      return $ s_brokerDeleteWorker broker worker
            | cmd == mdpwHeartbeat ->
                  if isWorkerReady
                  then do
                      currTime <- currentTime_ms
                      let newWorker = worker { expiry = currTime + heartbeatExpiry }
                      return newBroker { workers = M.insert (wId newWorker) newWorker (workers newBroker) }
                  else do 
                      s_workerSendDisconnect broker worker 
                      return $ s_brokerDeleteWorker broker worker
            | cmd == mdpwDisconnect ->
                  return $ s_brokerDeleteWorker broker worker
            | otherwise -> do
                  putStrLn "E: Invalid input message"
                  dumpMsg msg'
                  return newBroker

-- Process a request coming from a client.
-- TODO: Add modified service to broker!
s_brokerClientMsg :: Broker -> Frame -> Message -> IO (Broker, Service)
s_brokerClientMsg broker senderFrame msg = do
    when (L.length msg < 2) $ do
        error "E: Too little frames in message for client"

    let (serviceFrame, msg') = pop msg
        (service, newBroker) = s_serviceRequire broker serviceFrame
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
                     namedService = M.lookup name (services broker)
                 in  if isJust namedService && workersCount (fromJust namedService) > 0
                     then "200"
                     else "404"
            else "501"

s_brokerDeleteWorker :: Broker -> Worker -> Broker
s_brokerDeleteWorker broker worker = 
    let purgedServices = M.map purgeWorker (services broker)
    in  broker { bWaiting = L.delete worker (bWaiting broker)
               , workers = M.delete (wId worker) (workers broker) 
               , services = purgedServices}
  where purgeWorker service = 
            service { sWaiting = L.delete worker (sWaiting service)
                    , workersCount = workersCount service - 1 }
    
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
            key `notElem` (map wId toPurge)

        purgeWorkersFromServices workers = M.map purge
          where purge service =
                    let (toPurge, rest) = L.partition (\worker -> worker `elem` workers)
                                                      (sWaiting service)
                    in  service { sWaiting = rest
                                , workersCount = (workersCount service) - (length toPurge)
                                }

s_brokerGetServiceFor :: Worker -> Broker -> Service
s_brokerGetServiceFor worker broker =
    snd . head . M.toList $ M.filter containsWorker (services broker)
  where containsWorker service = L.elem worker (sWaiting service)


-- Service functions

-- Inserts a new service in the broker's services if that service didn't exist.
s_serviceRequire :: Broker -> Frame -> (Service, Broker)
s_serviceRequire broker serviceFrame =
    let foundService = M.lookup serviceFrame (services broker)
    in case foundService of
            Nothing -> createNewService
            Just fs -> (fs, broker)
  where createNewService =
            let newService = Service { name = serviceFrame -- TODO: base16 encode this
                                     , requests = []
                                     , sWaiting = []
                                     , workersCount = 0
                                     }
            in (newService
               , broker { services = M.insert (name newService) newService (services broker) })

-- TODO: Add modified service to broker!
s_serviceDispatch :: Broker -> Service -> Maybe Message -> IO (Broker, Service)
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
s_workerRequire :: Broker -> Frame -> (Worker, Broker)
s_workerRequire broker identity =
    let foundWorker = M.lookup identity (workers broker)
    in  case foundWorker of
            Nothing -> createNewWorker
            Just fw -> (fw, broker)
  where createNewWorker =
            let newWorker = Worker { wId = identity -- TODO: base16 encode this
                                   , identityFrame = [identity]
                                   , expiry = 0 -- The caller should modify it.
                                   }
            in  (newWorker
                , broker { workers = M.insert (wId newWorker) newWorker (workers broker) })

s_workerSendDisconnect :: Broker -> Worker -> IO () 
s_workerSendDisconnect broker worker =
    s_workerSend broker worker mdpwDisconnect Nothing Nothing

s_workerSend :: Broker -> Worker -> Frame -> Maybe Frame -> Maybe Message -> IO ()
s_workerSend broker worker cmd option msg = do
    let msgOpts = option : Just cmd : [Just mdpwWorker]
        msgFinal = wId worker : (concat . maybeToList $ msg) ++ (catMaybes msgOpts)
    when (verbose broker) $ do
        putStrLn $ "I: sending " ++ (B.unpack $ mdpsCommands !! mdpGetIdx (B.unpack cmd)) ++ " to worker"
        dumpMsg msgFinal
    sendMulti (bSocket broker) (N.fromList msgFinal)
  where getMsg (Just msg) = msg
        getMsg Nothing    = [B.empty]

-- TODO: Add modified service to broker
s_workerWaiting :: Broker -> Service -> Worker -> IO (Broker, Service)
s_workerWaiting broker wService worker = do
    currTime <- currentTime_ms
    let newWorker = worker { expiry = currTime + heartbeatExpiry }
        newService = wService { sWaiting = newWorker : sWaiting wService }
        newBroker = broker { bWaiting = newWorker : bWaiting broker }
    s_serviceDispatch newBroker newService Nothing


-- Main. Create a new broker and process messages on its socket.
main :: IO ()
main = 
    withBroker True $ \broker -> do
        s_brokerBind broker "tcp://*:5555"

        process broker
      where process broker = do
            [evts] <- poll (fromInteger $ heartbeatInterval) [Sock (bSocket broker) [In] Nothing]

            when (In `L.elem` evts) $ do
                msg <- receiveMulti (bSocket broker)
                when (verbose broker) $ do
                    putStrLn "I: Received message: "
                    dumpMsg msg

                let (sender, msg') = pop msg
                    (empty, msg'') = pop msg'
                    (header, finalMsg) = pop msg''
                case header of
                    head | head == mdpcClient -> do 
                                (newBroker, newService) <- s_brokerClientMsg broker sender finalMsg
                                process newBroker
                         | head == mdpwWorker -> do
                                newBroker <- s_brokerWorkerMsg broker sender finalMsg  
                                process newBroker
                         | otherwise -> do
                                putStrLn "E: Invalid message"
                                dumpMsg finalMsg
                                process broker
            
            currTime <- currentTime_ms
            when (currTime > heartbeatAt broker) $ do
                newBroker <- s_brokerPurge broker
                mapM_ (\worker -> s_workerSend newBroker worker mdpwHeartbeat Nothing Nothing) (bWaiting broker)
                -- TODO: Fetch currTime again
                process $ newBroker { heartbeatAt = currTime + heartbeatInterval }

            process broker
