-- |
-- Pub/Sub envelope publisher
-- |
module Main where

import System.ZMQ4.Monadic
import Control.Concurrent (threadDelay)
import Control.Monad (forever)
import Data.ByteString.Char8 (pack)

main :: IO ()
main =
    runZMQ $ do
        publisher <- socket Pub
        bind publisher "tcp://*:5563"
        forever $ do
            send publisher [SendMore] (pack "A")
            send publisher [] (pack "We don't want to see this")
            send publisher [SendMore] (pack "B")
            send publisher [] (pack "We would like to see this")
            liftIO $ threadDelay (1 * 1000 * 1000)
