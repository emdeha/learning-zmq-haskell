-- |
-- Pub/Sub broker
-- |
module Main where

import System.ZMQ4
import Data.ByteString.Char8 (pack)

main :: IO ()
main =  
    withContext $ \ctx ->
        withSocket ctx Sub $ \frontend ->
        withSocket ctx Pub $ \backend -> do
            bind frontend "tcp://*:5520"
            bind backend "tcp://*:5510"

            subscribe frontend (pack "")

            proxy frontend backend Nothing
