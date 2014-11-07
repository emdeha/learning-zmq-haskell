{-
    Majordomo Client API
-}
module MDClientAPI
    (   withMDCli
    ,   mdSetTimeout
    ,   mdSetRetries
    ,   mdSend
    ) where


import System.ZMQ4

import Control.Monad (when, liftM)
import Control.Applicative ((<$>))
import Control.Exception (bracket)
import Data.ByteString.Char8 (pack, unpack, empty, ByteString(..))
import qualified Data.List.NonEmpty as N

mdpcClient = "MDPCxy" 


data ClientAPI = ClientAPI {
      ctx :: Context
    , broker :: String
    , client :: Socket Req
    , verbose :: Bool
    , timeout :: Integer
    , retries :: Int
    }


withMDCli :: String -> Bool -> (ClientAPI -> IO a) -> IO a
withMDCli broker verbose act =
    bracket (mdInit broker verbose)
            (mdDestroy)
            act


{-
    @pre initialized context
    @post newly created client socket for the API 
-}
mdConnectToBroker :: ClientAPI -> IO ClientAPI
mdConnectToBroker api = do
    close $ client api
    reconnectedClient <- socket (ctx api) Req
    connect reconnectedClient (broker api)
    when (verbose api) $ do
        putStrLn $ "I: connecting to broker at " ++ (broker api)
    return api { client = reconnectedClient }

{-
    @pre valid broker ip address with port
    @post initialized API with connected socket to the broker
-}
mdInit :: String -> Bool -> IO ClientAPI
mdInit broker verbose = do
    ctx <- context
    client <- socket ctx Req
    let newAPI = ClientAPI { ctx = ctx
                           , client = client
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
mdDestroy :: ClientAPI -> IO ()
mdDestroy api = do
    close (client api)
    shutdown (ctx api)

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
  where trySend :: Socket Req -> Int -> [ByteString] -> IO [ByteString]
        trySend clientSock retries wrappedRequest = do
            putStrLn $ "msg " ++ (unwords $ unpack <$> wrappedRequest)
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
                if retries > 0
                then do
                    when (verbose api) $ putStrLn "W: No reply, reconnecting..."
                    mdConnectToBroker api
                    trySend clientSock (retries-1) wrappedRequest
                else do 
                    when (verbose api) $ putStrLn "W: Permanent error, abandoning"
                    error ""
