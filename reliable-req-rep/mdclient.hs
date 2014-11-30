import MDClientAPI

import ZHelpers

import Control.Monad (forM_)
import Data.ByteString.Char8 (unpack, pack)

main :: IO ()
main = 
    withMDCli "tcp://localhost:5555" True  $ \api ->
        forM_ [0..1000] $ \i -> do
            reply <- mdSend api "echo" [pack "Hello world"]
            putStrLn $ "Received: "
            dumpMsg reply
