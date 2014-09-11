-- |
-- Broker peering state flow prototype
-- |
import System.ZMQ4.Monadic

import System.Environment (getArgs)
import Control.Monad (forM_)
import Data.ByteString.Char8 (pack, unpack)


main :: IO ()
main =
    runZMQ $ do
        args <- liftIO $ getArgs

        if length args < 1
        then liftIO $ putStrLn "Syntax: peering1 me {you}...\n"        
        else do
            let self = args !! 0
            liftIO $ putStrLn $ "I: Preparing broker at " ++ self

            statebe <- socket Pub
            bind statebe ("tcp://*:" ++ self)

            statefe <- socket Sub
            subscribe statefe (pack "")
            forM_ [1..(length args - 1)] $ \i -> do
                liftIO $ putStrLn $ "II: Connecting to state backend at " ++ (args !! i)
                connect statefe ("tcp://localhost:"++(args!!i))
