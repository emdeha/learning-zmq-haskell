-- |
-- Request/Reply broker client
-- Binds REQ to tcp://lcoalhost:5559
-- |
module Main where

import System.ZMQ4.Monadic
import Control.Monad (forM_)
import Data.ByteString.Char8 (unpack, pack)

main :: IO ()
main =
    runZMQ $ do
        requester <- socket Req
        connect requester "tcp://localhost:5559"
        forM_ [1..10] $ \i -> do
            send requester [] (pack "Hello")
            rep <- receive requester
            liftIO $ putStrLn $ "Reply " ++ (show i) ++ (unpack rep)
