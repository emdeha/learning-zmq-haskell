-- |
-- Pub/Sub broker
-- |
module Main where

import System.ZMQ4.Monadic
import System.Random
import Control.Monad (forever)
import Data.ByteString.Char8 (pack)


getID :: IO Int
getID = getStdRandom (randomR (0, maxBound))


listenReqs :: ZMQ z ()
listenReqs = do
    id_resp_sock <- socket Rep
    bind id_resp_sock "tcp://*:6000"
    forever $ do
        req <- receive id_resp_sock
        id <- liftIO getID
        send id_resp_sock [] (pack $ show id)


main :: IO ()
main =  
    runZMQ $ do
        frontend <- socket Sub
        backend <- socket Pub

        bind frontend "tcp://*:5520"
        bind backend "tcp://*:5510"

        subscribe frontend (pack "")

        -- Start request listener
        async listenReqs
        -- Start message proxy
        proxy frontend backend Nothing
