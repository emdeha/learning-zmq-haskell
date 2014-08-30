-- |
-- Weather broadcast server in Haskell
-- Binds PUB socket to tcp://*5556
-- Publishes random weather updates
-- |
module Main where

import System.ZMQ4.Monadic
import Control.Monad (forever)
import Data.ByteString.Char8 (unpack, pack)
import System.Random (randomRIO)

main :: IO ()
main =
    runZMQ $ do
        publisher <- socket Pub
        bind publisher "tcp://*:5556"

        liftIO $ putStrLn "Established server..."

        forever $ do
            zipcode <- liftIO $ randomRIO (0::Int, 10000)
            temperature <- liftIO $ randomRIO (-80::Int, 135)
            humidity <- liftIO $ randomRIO (10::Int, 60)
            let update = pack $ unwords [show zipcode, show temperature, show humidity]
            send publisher [] update
            liftIO $ putStrLn $ "Sending update: " ++ (unpack update)
