-- |
-- Multiple socket poller in Haskell
-- |
module Main where

import System.ZMQ4
import Control.Monad (forever, when)
import Control.Applicative ((<$>))
import Data.ByteString.Char8 (unpack, pack)

main :: IO ()
main =
    withContext $ \ctx ->
        withSocket ctx Pull $ \receiver ->
        withSocket ctx Sub $ \subscriber -> do
            connect receiver "tcp://localhost:5557"
            setIdentity (restrict (pack "vent receiver")) receiver

            connect subscriber "tcp://localhost:5556"
            subscribe subscriber (pack "1001")

            forever $
                poll (-1) 
                     [ Sock receiver [In] (Just $ processEvts receiver)
                     , Sock subscriber [In] (Just $ processEvts subscriber)]

processEvts :: (Receiver a) => Socket a -> [Event] -> IO ()
processEvts sock evts =
    when (In `elem` evts) $ do
        msg <- unpack <$> receive sock
        ident <- unpack <$> identity sock
        putStrLn $ unwords ["Processing ", ident, msg]
