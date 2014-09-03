-- |
-- Request/Reply broker
-- Binds Router to tcp://*:5559
-- Binds Dealer to tcp://*:5560
-- |
module Main where

import System.ZMQ4.Monadic
import Control.Monad (forever, when)
import Control.Applicative ((<$>))
import Data.ByteString.Char8 (unpack, pack)

main :: IO ()
main =  
    runZMQ $ do
        frontend <- socket Router
        bind frontend "tcp://*:5559"
        backend <- socket Dealer
        bind backend "tcp://*:5560"

        -- |
        -- Using self-made proxy
        -- forever $ do
        --     poll (-1)
        --          [ Sock frontend [In] (Just $ processEvts fronend)
        --          , Sock backend [In] (Just $ processEvts backend)]
        -- |

        -- |
        -- Using the proxy function
        proxy frontend backend Nothing
        -- |

--processEvts :: (Receiver a) => Socket a -> [Event] -> IO ()
--processEvts sock evts =
--    when (In `elem` evts) $ d0
--        msg <- unpack <$> receive sock
--        send backend msg []
--        putStrLn $ unwords ["Sent ", msg]
