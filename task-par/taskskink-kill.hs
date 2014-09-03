-- |
-- Task sink which sends kill message to the workers
-- when they're done
-- |
module Main where

import System.ZMQ4.Monadic
import System.IO (hSetBuffering, stdout, BufferMode(..))
import Control.Monad (forM_)
import Data.Time.Clock (getCurrentTime, diffUTCTime)
import Data.ByteString.Char8 (pack)

main :: IO ()
main =
    runZMQ $ do
        receiver <- socket Pull
        bind receiver "tcp://*:5558"

        controller <- socket Pub
        bind controller "tcp://*:5559"

        receive receiver

        startTime <- liftIO getCurrentTime
        liftIO $ hSetBuffering stdout NoBuffering

        forM_ [1..100] $ \i -> do
            receive receiver
            liftIO $ putStr $ if i `mod` 10 == 0 then ":" else "."

        endTime <- liftIO getCurrentTime

        let elapsedTime = diffUTCTime endTime startTime
            elapsedMsec = elapsedTime * 1000
        liftIO $ putStrLn $ unwords ["Total elapsed time:", show elapsedMsec, "msecs"]

        -- send kill signal to workers
        send controller [] (pack "KILL")
