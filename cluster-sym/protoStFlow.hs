-- |
-- Broker peering state flow prototype
-- |
import System.ZMQ4.Monadic

import System.Environment (getArgs)
import System.Random (randomRIO)
import Control.Monad (forever, forM_)
import Data.ByteString.Char8 (pack, unpack)


type SockID = String

main :: IO ()
main =
    runZMQ $ do
        args <- liftIO $ getArgs

        if length args < 1
        then liftIO $ putStrLn "Syntax: peering1 me {you}...\n"        
        else do
            ((self, statebe), statefe) <- connectBrokers args
            pollBrokers (self, statebe) statefe


connectBrokers :: [String] -> ZMQ z ((SockID, Socket z Pub), Socket z Sub)
connectBrokers args = do
    let self = args !! 0
    liftIO $ putStrLn $ "I: Preparing broker at " ++ self

    statebe <- socket Pub
    bind statebe ("tcp://*:" ++ self)

    statefe <- socket Sub
    subscribe statefe (pack "")
    forM_ [1..(length args - 1)] $ \i -> do
        liftIO $ putStrLn $ "II: Connecting to state backend at " ++ (args !! i)
        connect statefe ("tcp://localhost:"++(args!!i))

    return ((self, statebe), statefe)


pollBrokers :: (SockID, Socket z Pub) -> Socket z Sub -> ZMQ z ()
pollBrokers (self, statebe) statefe =
    forever $ do
        [evts] <- poll 1000 [ Sock statefe [In] Nothing ]
        if In `elem` evts
        then do
            peerName <- receive statefe
            available <- receive statefe
            liftIO $ putStrLn $ (unpack peerName) ++ " - " ++ (unpack available) ++ " workers free"
        else do
            send statebe [SendMore] (pack self)
            rand <- liftIO $ randomRIO (0::Int, 10)
            send statebe [] (pack . show $ rand)
