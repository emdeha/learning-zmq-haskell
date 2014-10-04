module Main where

import System.ZMQ4.Monadic
import System.Random (randomRIO)
import System.Exit (exitSuccess)
import Control.Monad (forever, when)
import Control.Concurrent (threadDelay)
import Data.ByteString.Char8 (pack, unpack)


main :: IO ()
main =
    runZMQ $ do
        server <- socket Rep
        bind server "tcp://*:5555"

        sendClients 0 server

sendClients :: Int -> Socket z Rep -> ZMQ z ()
sendClients cycles server = do
    req <- receive server

    chance <- liftIO $ randomRIO (0::Int, 3)
    when (cycles > 3 && chance == 0) $ do
        simN <- liftIO $ randomRIO (0::Int, length simMap)
        liftIO $ simMap !! simN

    liftIO $ putStrLn $ "I: normal request " ++ (unpack req)
    liftIO $ threadDelay $ 1 * 1000 * 1000
    send server [] req

    sendClients (cycles+1) server

simMap :: [IO ()]
simMap = [crash, overload]

crash = do
    putStrLn "I: Simulating a crash"
    exitSuccess
overload = do 
    putStrLn "I: Simulating CPU overload"
    threadDelay $ 2 * 1000 * 1000
