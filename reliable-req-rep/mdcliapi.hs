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


data ClientAPI = ClientAPI {
      ctx :: Context
    , broker :: String
    , client :: Maybe (Socket Req)
    , verbose :: Bool
    , timeout :: Int
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
mdSetTimeout :: ClientAPI -> Int -> IO ClientAPI
mdSetTimeout api newTimeout = return api { timeout = newTimeout }

{-
    @pre initialized API
    @post new API with different retry count
-}
mdSetRetries :: ClientAPI -> Int -> IO ClientAPI
mdSetRetries api newRetries = return api { retries = newRetries }

mdSend = undefined
