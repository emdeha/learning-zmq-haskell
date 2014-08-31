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
import Data.ByteString.Char8 (pack, unpack)
import Control.Concurrent (threadDelay)


rand :: IO Int
rand = liftIO $ getStdRandom (randomR (0, maxBound))

sendInput :: (Sender b) => Socket z b -> ZMQ z ()
sendInput sock = do
    input <- liftIO $ getLine
    send sock [] (pack input)

main :: IO ()
main =  
    runZMQ $ do
        liftIO $ putStrLn "Establishing server..."
        repSocket <- socket Rep
        bind repSocket "tcp://*:5555"

        forever $ do
            msg <- receive repSocket
            (liftIO . putStrLn . unwords) ["Received request: ", unpack msg]

            liftIO $ threadDelay (1 * 1000 * 1000)

            if unpack msg == "id"
            then do 
                id <- liftIO $ rand
                send repSocket [] (pack $ show id)
            else sendInput repSocket
