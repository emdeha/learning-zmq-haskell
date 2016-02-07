{-
    Majordomo Async Client API
-}
module MDClientAPIAsync
    (   withMDCli
    ,   mdSetTimeout
    ,   mdSend
    ,   mdRecv
    ) where


import ZHelpers
import MDPDef
import System.ZMQ4

import Control.Monad (when, liftM)
import Control.Applicative ((<$>))
import Control.Exception (bracket)
import Data.ByteString.Char8 (pack, unpack, empty, ByteString(..))
import qualified Data.List.NonEmpty as N


data ClientAPI = ClientAPI {
      ctx :: Context
    , broker :: String
    , client :: Socket Dealer
    , verbose :: Bool
    , timeout :: Integer
    }


withMDCli :: String -> Bool -> (ClientAPI -> IO a) -> IO a
withMDCli broker verbose act =
    bracket (mdInit broker verbose)
            (mdDestroy)
            act

{-
    Public API
-}
mdSetTimeout :: ClientAPI -> Integer -> IO ClientAPI
mdSetTimeout api newTimeout = return api { timeout = newTimeout }

-- Sends one message without waiting for reply. Adds empty frame at message start
-- to emulate Req socket.
mdSend :: ClientAPI -> String -> Message -> IO ()
mdSend api service request = do
    let wrappedRequest = [empty, mdpcClient, pack service] ++ request
    when (verbose api) $ do
        putStrLn $ "I: Send request to " ++ service ++ " service:"
        dumpMsg wrappedRequest 
   
    sendMulti (client api) (N.fromList wrappedRequest)

-- Waits for reply message and returns it to the caller.
mdRecv :: ClientAPI -> IO (Maybe Message)
mdRecv api = do
    [evts] <- poll (fromInteger $ timeout api) [Sock (client api) [In] Nothing] 

    if In `elem` evts
    then do
        msg <- receiveMulti (client api)
        when (verbose api) $ do
            putStrLn "I: received reply"
            dumpMsg msg

        when (length msg < 3) $ do
            putStrLn "E: Malformed message"
            dumpMsg msg
            error ""

        let (header, msg') = z_pop . snd . z_pop $ msg
            (reply_service, msg'') = z_pop msg'
        when (header /= mdpcClient) $
            error $ "E: Malformed header '" ++ (unpack header) ++ "'"

        return (Just msg'')
    else do
        when (verbose api) $ 
            putStrLn "W: Permanent error, abandoning"
        return Nothing


{-
    Private API
-}
mdConnectToBroker :: ClientAPI -> IO ClientAPI
mdConnectToBroker api = do
    close $ client api
    reconnectedClient <- socket (ctx api) Dealer
    connect reconnectedClient (broker api)
    when (verbose api) $ do
        putStrLn $ "I: connecting to broker at " ++ (broker api)
    return api { client = reconnectedClient }

mdInit :: String -> Bool -> IO ClientAPI
mdInit broker verbose = do
    ctx <- context
    client <- socket ctx Dealer
    let newAPI = ClientAPI { ctx = ctx
                           , client = client
                           , broker = broker
                           , verbose = verbose
                           , timeout = 0
                           }
    mdConnectToBroker newAPI

mdDestroy :: ClientAPI -> IO ()
mdDestroy api = do
    close (client api)
    shutdown (ctx api)
