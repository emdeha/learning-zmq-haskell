-- |
-- Task worker which responds to kill signal
-- from the sink
-- |
module Main where

import System.ZMQ4
import System.IO (hSetBuffering, stdout, BufferMode(..))
import Data.ByteString.Char8 (unpack, pack, empty)
import Control.Concurrent (threadDelay)
import Control.Applicative ((<$>))
import Control.Monad (when, unless)

main :: IO ()
main =
    withContext $ \ctx ->
        withSocket ctx Pull $ \receiver ->
        withSocket ctx Push $ \sender ->
        withSocket ctx Sub $ \controller -> do
            connect receiver "tcp://localhost:5557"
            connect sender "tcp://localhost:5558"
            connect controller "tcp://localhost:5559"
            subscribe controller (pack "")
            hSetBuffering stdout NoBuffering
            pollContinuously receiver sender controller

pollContinuously :: 
    (Receiver r, Sender s) => Socket r -> Socket s -> Socket c -> IO ()
pollContinuously sock_recv sock_send controller = do
    [a, b] <- poll (-1) [ Sock sock_recv [In] Nothing
                        , Sock controller [In] Nothing]

    when (In `elem` a) $ do
        msg <- unpack <$> receive sock_recv
        putStr $ msg ++ "."
        threadDelay (read msg * 1000)
        send sock_send [] empty

    unless (In `elem` b) $
        pollContinuously sock_recv sock_send controller
