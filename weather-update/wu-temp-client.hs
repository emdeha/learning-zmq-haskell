-- |
-- Weather broadcast client in Haskell
-- Binds SUB socket to tcp://localhost:5556
-- Collects temperatures for given zipcode
-- |
module Main where

import System.ZMQ4.Monadic
import Control.Monad (forever)
import Data.ByteString.Char8 (pack, unpack)

main :: IO ()
main =
    runZMQ $ do
        subscriber <- socket Sub
        connect subscriber "tcp://localhost:5556"
        subscribe subscriber (pack "1001")

        liftIO $ putStrLn "Established temperature client..."

        forever $ do
            update <- receive subscriber
            let [_, temp, _] = words $ unpack update
            liftIO $ putStrLn $ "Temp received: " ++ temp
