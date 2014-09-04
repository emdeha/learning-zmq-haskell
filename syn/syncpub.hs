-- |
-- Node coordination publisher
-- |
module Main where

import System.ZMQ4.Monadic
import System.IO (hSetBuffering, stdout, BufferMode(..))
import Control.Monad (replicateM_, unless)
import Data.ByteString.Char8 (unpack, pack, empty)
import Text.Printf

subscribersExpected = 10
nbOfUpdate = 10000

sync :: Socket z Rep -> ZMQ z ()
sync = loop 0
    where 
        loop num sock = 
            unless (num >= subscribersExpected) $ do
                receive sock >>= \msg -> liftIO $ printf "Received: %s\n" (unpack msg)
                send sock [] empty
                loop (num+1) sock

main :: IO ()
main =
    runZMQ $ do
        publisher <- socket Pub
        setSendHighWM (restrict nbOfUpdate) publisher
        bind publisher "tcp://*:5561"

        syncservice <- socket Rep
        bind syncservice "tcp://*:5562"

        liftIO $ hSetBuffering stdout NoBuffering
        liftIO $ putStrLn "Syncing..."
        sync syncservice

        liftIO $ putStrLn "Sending updates..."
        replicateM_ nbOfUpdate $ send publisher [] (pack "Rhubarb")

        liftIO $ putStrLn "Terminating"
        send publisher [] (pack "END")
