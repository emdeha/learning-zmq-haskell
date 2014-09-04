-- |
-- Multithreaded Hello World server
-- (Client) REQ >-> ROUTER (Proxy) DEALER >-> REP ([Worker])
-- |
module Main where

import System.ZMQ4.Monadic
import Control.Monad (forever, replicateM_)
import Control.Concurrent (threadDelay)
import Data.ByteString.Char8 (unpack, pack)
import Text.Printf

main :: IO ()
main =
    runZMQ $ do
        -- Server frontend socket to talk to clients
        server <- socket Router
        bind server "tcp://*:5555"

        -- Socket to talk to clients
        workers <- socket Dealer
        bind workers "inproc://workers"

        -- using inproc (inter-thread) we expect to share the same context
        replicateM_ 5 (async worker)
        -- connect work threads to client threads via a queue
        proxy server workers Nothing 

worker :: ZMQ z ()
worker = do
    receiver <- socket Rep
    connect receiver "inproc://workers"
    forever $ do
        receive receiver >>= liftIO . printf "Received request: %s\n" . unpack
        liftIO $ threadDelay (1 * 1000 * 1000)
        send receiver [] (pack "World")
