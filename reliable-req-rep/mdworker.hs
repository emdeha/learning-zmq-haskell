import MDWorkerAPI

import Control.Monad (forever, mapM_)
import Data.ByteString.Char8 (unpack, empty, ByteString(..))
import System.IO (hSetBuffering, stdout, BufferMode(NoBuffering))

main :: IO ()
main = do
    hSetBuffering stdout NoBuffering

    withMDWorker "tcp://localhost:5555" "echo" True $ \session ->
        forever $ do
            request <- mdwkrExchange session [empty]
            mapM_ (putStrLn . unpack) (snd request)
