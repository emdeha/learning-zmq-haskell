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
import Control.Concurrent (threadDelay)
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

    , expect_reply :: Bool
    , reply_to :: [ByteString]
    }

heartbeatLiveness :: Int
heartbeatLiveness = 3


{-
    Public API
-}
withMDWorker :: String -> String -> Bool -> (WorkerAPI -> IO a) -> IO a
withMDWorker broker service verbose session = do
    bracket (mdwkrInit broker service verbose) 
            (mdwkrDestroy)
            (session)

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
                           , expect_reply = False
                           , reply_to = [empty]
                           }
    s_mdwkrConnectToBroker newAPI

-- Send reply to broker and wait for request
-- TODO: Use state
mdwkrExchange :: WorkerAPI -> [ByteString] -> IO (WorkerAPI, [ByteString])
mdwkrExchange api reply = do
    s_mdwkrSendToBroker api mdpwReply Nothing (Just $ reply_to api ++ reply) 

    tryExchange api { expect_reply = True }
  where tryExchange :: WorkerAPI -> IO (WorkerAPI, [ByteString])
        tryExchange api = do
            [evts] <- poll (fromInteger $ heartbeatDelay_ms api) [Sock (worker api) [In] Nothing]

            if In `elem` evts
            then do
                msg <- receiveMulti $ worker api
                when (verbose api) $ do
                    putStrLn $ "I: Received message from broker: "
                    mapM_ (putStrLn . unpack) msg
                
                when (length msg <= 3) $ do
                    putStrLn $ "E: Invalid message format"
                    error ""

                let empty_ = msg !! 0
                    header = msg !! 1
                    command = msg !! 2
                -- TODO: error "msg", instead of putStrLn
                when (empty_ /= empty) $ do
                    putStrLn $ "E: Not an empty first frame"
                    error ""
                when (header /= mdpwWorker) $ do
                    putStrLn $ "E: Not a valid MDP header"
                    error ""

                case command of
                    cmd | cmd == mdpwRequest -> return (api { reply_to = drop 3 msg 
                                                       , liveness = heartbeatLiveness
                                                       , expect_reply = True
                                                       }, msg )
                        | cmd == mdpwDisconnect -> do
                              newAPI <- s_mdwkrConnectToBroker $ api { liveness = heartbeatLiveness
                                                                     , expect_reply = True }
                              tryExchange newAPI
                        | cmd == mdpwHeartbeat -> do
                              tryExchange api { expect_reply = True }
                        | otherwise -> do
                              putStrLn "E: Invalid input message"
                              mapM_ (putStrLn . unpack) msg
                              tryExchange api { expect_reply = True }
            else do
                if (liveness api == 0)
                then do
                    when (verbose api) $ do
                        putStrLn "W: Disconnected from broker - retrying..."
                    threadDelay ((fromInteger $ reconnectDelay_ms api) * 1000)
                    newAPI <- s_mdwkrConnectToBroker api
                    tryExchange newAPI { expect_reply = True }
                else do
                    currTime <- currentTime_ms
                    if (currTime > heartbeat_at api) 
                    then do
                        s_mdwkrSendToBroker api mdpwHeartbeat Nothing Nothing
                        nextHeartbeat <- nextHeartbeatTime_ms $ heartbeatDelay_ms api
                        tryExchange api { heartbeat_at = nextHeartbeat
                                        , expect_reply = True }
                    else tryExchange api { expect_reply = True }

mdwkrSetReconnect :: WorkerAPI -> Integer -> IO WorkerAPI
mdwkrSetReconnect api newReconnectDelay_ms = 
    return api { reconnectDelay_ms = newReconnectDelay_ms }

mdwkrSetHeartbeat :: WorkerAPI -> Integer -> IO WorkerAPI
mdwkrSetHeartbeat api newHeartbeatDelay_ms = 
    return api { heartbeatDelay_ms = newHeartbeatDelay_ms }

{-
    Private API
-}
mdwkrDestroy :: WorkerAPI -> IO ()
mdwkrDestroy api = do
    close (worker api)
    shutdown (ctx api)

{-
    Helper functions
-}
s_mdwkrSendToBroker :: WorkerAPI -> ByteString -> Maybe ByteString -> Maybe [ByteString] -> IO ()
s_mdwkrSendToBroker api command option msg = do
    let args = [option, Just command, Just mdpwWorker, Just empty]
        msg' = fromMaybe [] msg
        wrappedMessage = msg' ++ catMaybes args
    when (verbose api) $ do
        let strCmd = mdpsCommands !! (mdpGetIdx . unpack $ command)
        putStrLn $ "I: Sending " ++ unpack strCmd ++ " to broker"
        mapM_ (putStrLn . unpack) wrappedMessage

    sendMulti (worker api) (N.fromList wrappedMessage)

s_mdwkrConnectToBroker :: WorkerAPI -> IO WorkerAPI
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
