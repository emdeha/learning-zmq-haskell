-- |
-- Simple chat server
-- |
module Main where

import System.ZMQ4
import Control.Monad (forever)
import Data.ByteString.Char8 (unpack, pack)

main :: IO ()
main =
    withContext $ \ctx ->
        withSocket ctx Pub $ \out_sock ->
        withSocket ctx Sub $ \in_sock -> do
            connect out_sock "tcp://localhost:5510"
            connect in_sock "tcp://localhost:5520" 

            subscribe in_sock (pack "")

            forever $ do
                receive in_sock >>= send out_sock []
