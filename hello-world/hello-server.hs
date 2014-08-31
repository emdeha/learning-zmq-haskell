-- |
-- Simple server in Haskell
-- Assigns IDs to every new client
-- Receives data
-- Sends response
-- |
module Main where

import System.ZMQ4.Monadic
import System.Random
import Control.Monad (forever)
import Control.Concurrent (threadDelay)
import Data.ByteString.Char8 (pack, unpack)


rand :: IO Int
rand = liftIO $ getStdRandom (randomR (0, maxBound))

sendID :: (Sender b) => Socket z b -> ZMQ z ()
sendID sender = do
    id <- liftIO $ rand
    send sender [] (pack $ show id)

sendInput :: (Sender b) => Socket z b -> ZMQ z ()
sendInput sender = do
    input <- liftIO $ getLine
    send sender [] (pack input)

main :: IO ()
main =  
    runZMQ $ do
        liftIO $ putStrLn "Establishing server..."
        repSocket <- socket Rep
        bind repSocket "tcp://*:5555"

        forever $ do
            msg <- receive repSocket
            (liftIO . putStrLn . unwords) [unpack msg]

            liftIO $ threadDelay (1 * 1000 * 1000)

            if unpack msg == "id"
            then sendID repSocket
            else sendInput repSocket
