-- |
-- Request/Reply broker
-- Binds Router to tcp://*:5559
-- Binds Dealer to tcp://*:5560
-- |
module Main where

import System.ZMQ4.Monadic

main :: IO ()
main =  
    runZMQ $ do
        frontend <- socket Router
        bind frontend "tcp://*:5559"
        backend <- socket Dealer
        bind backend "tcp://*:5560"

        proxy frontend backend Nothing
