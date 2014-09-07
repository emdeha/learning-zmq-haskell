-- |
-- Simple chat client
-- 6000 id/partner request socket ("gid" - GetID, "gp""<partner_name>" - GetPartner)
-- 5520 publishing socket
-- 5510 subscribing socket
-- |
module Main where

import System.ZMQ4.Monadic
import System.IO (hSetBuffering, stdout, BufferMode(..))
import Control.Monad (forever)
import Data.ByteString.Char8 (unpack, pack)


requestId :: ZMQ z String
requestId = do
    id_sock <- socket Req
    connect id_sock "tcp://localhost:6000"
    send id_sock [] (pack "gid")        
    id <- receive id_sock
    return $ unpack id

receiveMessage :: ZMQ z ()
receiveMessage = do
    in_sock <- socket Sub

    connect in_sock "tcp://localhost:5510" 

    liftIO $ putStr "partner? "
    partner <- liftIO $ getLine
    subscribe in_sock (pack partner)

    forever $ do
        msg <- receive in_sock
        liftIO $ putStrLn (unpack msg)

sendMessage :: ZMQ z ()
sendMessage = do
    out_sock <- socket Pub
    connect out_sock "tcp://localhost:5520"

    id <- requestId
    liftIO $ hSetBuffering stdout NoBuffering
    liftIO $ putStrLn $ "id received: " ++ id

    forever $ do
        resp <- liftIO $ getLine
        send out_sock [SendMore] (pack id)
        send out_sock [] (pack resp)
        

main :: IO ()
main = 
    runZMQ $ do
        async sendMessage
        async receiveMessage
