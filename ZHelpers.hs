module ZHelpers where

import System.ZMQ4.Monadic

import Numeric (showHex)

import Control.Applicative ((<$>))
import Control.Monad (when)
import System.Random
import System.Locale
import Data.Time
import Data.ByteString.Char8 (pack, unpack)
import Data.Char (ord)
import Text.Printf (printf)
import qualified Data.ByteString as B


type Frame = B.ByteString
type Message = [Frame]


dumpMsg :: [B.ByteString] -> IO ()
dumpMsg msg_parts = do
    putStrLn "----------------------------------------"
    mapM_ (\i -> putStr (printf "[%03d] " (B.length i)) >> func (unpack i)) msg_parts where
        func :: String -> IO ()
        func item | all (\c -> (ord c >= 32) && (ord c <= 128)) item = putStrLn item 
                  | otherwise   = putStrLn $ prettyPrint $ pack item

dumpSock :: Receiver t => Socket z t  -> ZMQ z ()
dumpSock sock = fmap reverse (receiveMulti sock) >>= liftIO . dumpMsg

-- In General Since We use Randomness, You should Pass in
-- an StdGen, but for simplicity we just use newStdGen
setRandomIdentity :: Socket z t -> ZMQ z ()
setRandomIdentity sock = liftIO genUniqueId >>= (\ident -> setIdentity (restrict $ pack ident) sock)


-- You probably want to use a ext lib to generate random unique id in production code
genUniqueId :: IO String
genUniqueId = do
    gen <- liftIO newStdGen
    let (val1, gen') = randomR (0 :: Int, 65536) gen
    let (val2, _) = randomR (0 :: Int, 65536) gen'
    return $ show val1 ++ show val2

-- In General Since We use Randomness, You should Pass in
-- an StdGen, but for simplicity we just use newStdGen
--genKBytes :: Int -> IO B.ByteString
--genKBytes k = do
--    gen <- newStdGen
--    bs <- foldM (\(g, s) _i -> let (val, g') = random g in return (g', cons val s)) (gen, empty) [1..k]
--    return $ snd bs

prettyPrint :: B.ByteString -> String
prettyPrint = concatMap (`showHex` "") . B.unpack

-- Returns the current UNIX time in milliseconds
currentTime_ms :: IO Integer
currentTime_ms = do
    time_secs <- (read <$> formatTime defaultTimeLocale "%s" <$> getCurrentTime) :: IO Integer
    return $ time_secs * 1000

nextHeartbeatTime_ms :: Integer -> IO Integer
nextHeartbeatTime_ms heartbeatInterval_ms = do
    currTime <- currentTime_ms
    return $ currTime + heartbeatInterval_ms

-- Simple assertion mechanism
z_assert :: Bool -> String -> IO ()
z_assert pred msg = when (not pred) $ error msg

-- Message frames util functions
--

-- Push frame plus empty frame before first frame.
wrap :: Message -> Frame -> Message
wrap msg frame = frame : B.empty : msg

-- Push frame before all frames
push :: Message -> Frame -> Message
push msg frame = frame : msg

-- Pop first frame from message.
-- Returns an empty frame/message pair if there's nothing in the message in order to
-- make more convenient the construction of new messages on the fly.
-- TODO: Think how to put a Maybe in here.
pop :: Message -> (Frame, Message)
pop [] = (B.empty, [B.empty])
pop [frame] = (frame, [B.empty])
pop (frame:rest) = (frame, rest)
