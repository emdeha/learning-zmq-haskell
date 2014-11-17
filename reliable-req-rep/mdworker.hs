import MDWorkerAPI

import Control.Monad (forever, mapM_)
import Data.ByteString.Char8 (unpack, empty, ByteString(..))

main :: IO ()
main =
    withMDWorker "tcp://localhost:5555" "echo" True $ \session ->
        forever $ do
            request <- mdwkrExchange session [empty]
            mapM_ (putStrLn . unpack) (snd request)
