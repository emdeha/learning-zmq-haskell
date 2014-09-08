module ZHelpers where

import System.ZMQ4.Monadic

import Numeric (showHex)

import Data.ByteString.Char8 (pack, unpack)
import Data.Char (ord)
import Text.Printf (printf)
import System.Random
import qualified Data.ByteString as B


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
