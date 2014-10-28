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

import Control.Monad (when)


data ClientAPI = ClientAPI {
      ctx :: Context
    , broker :: String
    , client :: Socket Req
    , verbose :: Bool
    , timeout :: Int
    , retries :: Int
    }


mdConnectToBroker :: ClientAPI -> IO ClientAPI
mdConnectToBroker api = do
    client <- socket (ctx api) Req
    connect client (broker api)
    when (verbose api) $ do
        putStrLn $ "I: connecting to broker at " ++ (broker api)
    return api { client = client }

mdInit = undefined

mdDestroy = undefined

mdSetTimeout = undefined

mdSetRetries = undefined

mdSend = undefined
