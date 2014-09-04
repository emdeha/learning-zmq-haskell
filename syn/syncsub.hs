-- |
-- Node coordination subscriber
-- |
module Main where

import System.ZMQ4.Monadic
import Data.ByteString.Char8 (unpack, pack)
import Control.Concurrent (threadDelay)
import Text.Printf

main :: IO ()
main =
    runZMQ $ do
        subscriber <- socket Sub
        connect subscriber "tcp://localhost:5561"
        subscribe subscriber (pack "")

        -- Sleep one second to make sure that the Sub socket has been connected
        -- before the Req socket
        liftIO $ threadDelay $ 1 * 1000 * 1000

        syncclient <- socket Req
        connect syncclient "tcp://localhost:5562"

        send syncclient [] (pack "sync request")
        receive syncclient

        countUpdates subscriber >>= liftIO . printf "Received %d updates\n"
        liftIO $ threadDelay $ 10 * 1000 * 1000

countUpdates :: Socket z Sub -> ZMQ z Int
countUpdates = loop 0
    where 
        loop val sock = do
            msg <- receive sock
            if unpack msg == "END"
            then return val
            else loop (val+1) sock
