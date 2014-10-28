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


mdConnectToBroker :: ClientAPI -> IO ClientAPI
mdConnectToBroker api = do
    case client api of Just cl -> close cl
    client <- socket (ctx api) Req
    connect client (broker api)
    when (verbose api) $ do
        putStrLn $ "I: connecting to broker at " ++ (broker api)
    return api { client = Just client }

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

mdDestroy = undefined

mdSetTimeout = undefined

mdSetRetries = undefined

mdSend = undefined
