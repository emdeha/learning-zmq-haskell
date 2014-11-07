import MDClientAPI

import Control.Monad (forM_)
import Data.ByteString.Char8 (pack)

main :: IO ()
main = 
    withMDCli "tcp://localhost:5555" True  $ \api ->
        forM_ [0..1000] $ \i -> do
            mdSend api "echo" [pack "Hello world"]
