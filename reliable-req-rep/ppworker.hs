{-
Paranoid Pirate worker in Haskell.
Uses heartbeating to detect crashed queue.
-}
module Main where

import System.ZMQ4.Monadic

main :: IO ()
main = 
    runZMQ $ do undefined
