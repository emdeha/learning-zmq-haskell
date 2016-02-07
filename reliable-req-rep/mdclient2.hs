import MDClientAPIAsync

import ZHelpers

import System.Environment (getArgs)
import System.IO (hSetBuffering, stdout, BufferMode(NoBuffering))
import Control.Monad (forM_, when)
import Data.ByteString.Char8 (unpack, pack)
import Data.Maybe (fromMaybe, fromJust)

main :: IO ()
main = do
    args <- getArgs
    when (length args /= 1) $
        error "usage: mdclient2 <isVerbose(True|False)>"
    let isVerbose = read (args !! 0) :: Bool

    hSetBuffering stdout NoBuffering

    withMDCli "tcp://localhost:5555" isVerbose $ \api -> do
        forM_ [0..10000] (\i -> do
            mdSend api "echo" [pack "Hello world"])
        forM_ [0..10000] (\i -> do
            mdRecv api)
            --putStrLn $ show i)
            --dumpMsg $ fromJust msg)
        putStrLn "processed 10000 replies"
