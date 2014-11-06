{-
    Majordomo Client API
-}
module MDClientAPI
    (   mdConnectToBroker
    ,   mdInit
    ,   mdDestroy
    ,   mdSetTimeout
    ,   mdSetRetries
    ,   mdSend
    ) where


import System.ZMQ4

import Control.Monad (when, liftM)
import Data.ByteString.Char8 (pack, unpack, empty, ByteString(..))
import qualified Data.List.NonEmpty as N

mdpcClient = "MDPCxy" 


data ClientAPI = ClientAPI {
      ctx :: Context
    , broker :: String
    , client :: Maybe (Socket Req)
    , verbose :: Bool
    , timeout :: Integer
    , retries :: Int
    }


{-
    @pre initialized context
    @post newly created client socket for the API 
-}
mdConnectToBroker :: ClientAPI -> IO ClientAPI
mdConnectToBroker api = do
    case client api of Just cl -> close cl
    client <- socket (ctx api) Req
    connect client (broker api)
    when (verbose api) $ do
        putStrLn $ "I: connecting to broker at " ++ (broker api)
    return api { client = Just client }

{-
    @pre valid broker ip address with port
    @post initialized API with connected socket to the broker
-}
mdInit :: String -> Bool -> IO ClientAPI
mdInit broker verbose = do
    ctx <- context
    let newAPI = ClientAPI { ctx = ctx
                           , client = Nothing
                           , broker = broker
                           , verbose = verbose
                           , timeout = 2500
                           , retries = 3
                           }
    mdConnectToBroker newAPI

{-
    @pre initialized context
    @post an API _without a created context_ and _closed sockets_
-}
mdDestroy :: ClientAPI -> IO ClientAPI
mdDestroy api = do
    case client api of Just cl -> close cl
    shutdown (ctx api)
    return api

{-
    @pre initialized API
    @post new API with different timeout
-}
mdSetTimeout :: ClientAPI -> Integer -> IO ClientAPI
mdSetTimeout api newTimeout = return api { timeout = newTimeout }

{-
    @pre initialized API
    @post new API with different retry count
-}
mdSetRetries :: ClientAPI -> Int -> IO ClientAPI
mdSetRetries api newRetries = return api { retries = newRetries }

{-
    @brief Sends a request and retries until it can
    @pre initialized API
    @post unaltered API
-}
mdSend :: ClientAPI -> String -> [ByteString] -> IO [ByteString]
mdSend api service request = do
    -- Protocol frames
    -- Frame 1: "MDPCxy" (six bytes, MDP/Client x.y)
    -- Frame 2: Service name (printable string)
    let wrappedRequest = [pack mdpcClient, pack service] ++ request
    when (verbose api) $ do
        putStrLn $ "I: Send request to " ++ service ++ " service:"
        mapM_ (putStrLn . unpack) wrappedRequest 
   
    trySend (client api) (retries api) wrappedRequest
  where trySend :: Maybe (Socket Req) -> Int -> [ByteString] -> IO [ByteString]
        trySend Nothing _ _ = error "E: Socket not connected"
        trySend (Just clientSock) retries wrappedRequest = do
            sendMulti clientSock (N.fromList wrappedRequest)

            evts <- poll (fromInteger $ timeout api) [Sock clientSock [In] Nothing] 
            if In `elem` (evts !! 0)
            then do
                msg <- receiveMulti clientSock
                when (verbose api) $ do
                    putStrLn "I: received reply"
                    mapM_ (putStrLn . unpack) msg

                when (length msg < 3) $ do
                    putStrLn "E: Malformed message"
                    mapM_ (putStrLn . unpack) msg
                    error ""

                let header = unpack $ msg !! 0
                    reply_service = unpack $ msg !! 1
                when (header /= mdpcClient) $ do
                    putStrLn "E: Malformed message"
                    mapM_ (putStrLn . unpack) msg
                    error ""
                when (reply_service /= service) $ do
                    putStrLn "E: Malformed message"
                    mapM_ (putStrLn . unpack) msg
                    error ""

                return $ drop 2 msg
            else
                if retries < 0
                then do
                    when (verbose api) $ putStrLn "W: No reply, reconnecting..."
                    mdConnectToBroker api
                    trySend (Just clientSock) (retries-1) wrappedRequest
                else do 
                    when (verbose api) $ putStrLn "W: Permanent error, abandoning"
                    error ""
