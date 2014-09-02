-- |
-- Request/Reply broker worker
-- Binds REP to tcp://localhost:5560
-- |
module Main where

import System.ZMQ4.Monadic
import Control.Monad (forever)
import Control.Concurrent (threadDelay)
import Data.ByteString.Char8 (unpack, pack)

main :: IO ()
main =
    runZMQ $ do
        responder <- socket Rep
        connect responder "tcp://localhost:5560"

        forever $ do
            msg <- receive responder
            liftIO $ putStrLn $ "Request " ++ (unpack msg)
            liftIO $ threadDelay (1 * 1000 * 1000)
            send responder [] (pack "World")
