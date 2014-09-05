-- |
-- Simple chat client
-- 6000 id/partner request socket ("gid" - GetID, "gp""<partner_name>" - GetPartner)
-- 5520 publishing socket
-- 5510 subscribing socket
-- |
module Main where

import System.ZMQ4
import Control.Monad (forever)
import Data.ByteString.Char8 (unpack, pack)


requestId :: Context -> IO String
requestId ctx =
    withSocket ctx Req $ \id_sock -> do
        connect id_sock "tcp://localhost:6000"
        send id_sock [] (pack "gid")        
        id <- receive id_sock
        return $ unpack id


main :: IO ()
main = 
    withContext $ \ctx ->
        withSocket ctx Pub $ \out_sock ->
        withSocket ctx Sub $ \in_sock -> do
            connect out_sock "tcp://localhost:5520"
            connect in_sock "tcp://localhost:5510" 

            id <- requestId ctx
            putStrLn $ "id received: " ++ id

            putStr "partner? "
            partner <- getLine
            subscribe in_sock (pack partner)

            forever $ do
                resp <- getLine
                send out_sock [SendMore] (pack id)
                send out_sock [] (pack resp)
                msg <- receive in_sock
                putStrLn (unpack msg)
