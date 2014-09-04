-- |
-- Pub/Sub broker
-- Binds Router to tcp://*:5559
-- Binds Dealer to tcp://*:5560
-- |
module Main where

import System.ZMQ4

main :: IO ()
main =  
    withContext $ \ctx ->
        withSocket ctx Router $ \frontend ->
        withSocket ctx Dealer $ \backend -> do
            bind frontend "tcp://*:5510"
            bind backend "tcp://*:5520"

            proxy frontend backend Nothing
