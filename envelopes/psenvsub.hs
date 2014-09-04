-- |
-- Pub/Sub envelope subscriber
-- |
module Main where

import System.ZMQ4.Monadic
import Data.ByteString.Char8 (unpack, pack)
import Control.Monad (when)
import Control.Concurrent (threadDelay)
import Text.Printf

main :: IO ()
main =
    runZMQ $ do
        subscriber <- socket Sub
        connect subscriber "tcp://localhost:5563"
        subscribe subscriber (pack "B")

        loop subscriber

loop :: Socket z Sub -> ZMQ z ()
loop subscriber = do
    receive subscriber >>= \addr -> liftIO $ printf "Address %s\n" (unpack addr)

    more <- moreToReceive subscriber
    when more $ do
        contents <- receive subscriber
        liftIO $ putStrLn (unpack contents)
    loop subscriber
