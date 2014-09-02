-- |
-- Simple multipart message sender in Haskell
-- |
module Main where

import System.ZMQ4.Monadic
import Control.Monad (forever)
import Control.Concurrent (threadDelay)
import Data.ByteString.Char8 (pack, unpack)

main :: IO ()
main =
    runZMQ $ do
        liftIO $ putStrLn "Establishing server..."
        pubSocket <- socket Pub
        bind pubSocket "tcp://*:5555"

        forever $ do
            send pubSocket [SendMore] (pack "Hello...")
            send pubSocket [SendMore] (pack "How are...")
            send pubSocket [] (pack "you?")
            liftIO $ putStrLn $ "Queued messages..."
