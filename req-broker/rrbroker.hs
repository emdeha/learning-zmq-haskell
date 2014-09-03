-- |
-- Request/Reply broker
-- Binds Router to tcp://*:5559
-- Binds Dealer to tcp://*:5560
-- |
module Main where

import System.ZMQ4
import Control.Monad (forever, when)
import Control.Applicative ((<$>))
import Data.ByteString.Char8 (unpack, pack)

main :: IO ()
main =  
    withContext $ \ctx ->
        withSocket ctx Router $ \frontend ->
        withSocket ctx Dealer $ \backend -> do
            bind frontend "tcp://*:5559"
            bind backend "tcp://*:5560"

            -- |
            -- Using self-made proxy
            doProxy frontend backend
            -- |

            -- |
            -- Using the proxy function
            -- proxy frontend backend Nothing
            -- |

doProxy :: (Sender a, Receiver a, Sender b, Receiver b) => Socket a -> Socket b -> IO ()
doProxy frontend backend = do
    forever $ do
        [fr, back] <- poll (-1) [ Sock frontend [In] Nothing 
                                , Sock backend [In] Nothing]

        when (In `elem` fr) $ do
            msg <- receive frontend
            putStrLn $ (unpack msg) 
            send backend [] msg

        when (In `elem` back) $ do
            msg <- receive backend
            putStrLn $ (unpack msg)
            send frontend [] msg
