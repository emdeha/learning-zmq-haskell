module Main where

import System.ZMQ4.Monadic
import ZHelpers (dumpSock)
import Data.ByteString.Char8 (pack)

main :: IO ()
main =
    runZMQ $ do
        sink <- socket Router
        bind sink "inproc://example"

        anonymous <- socket Req
        connect anonymous "inproc://example"
        send anonymous [] (pack "ROUTER uses generated UUID")

        dumpSock sink

        identified <- socket Req
        setIdentity (restrict $ pack "PEER2") identified
        connect identified "inproc://example"
        send identified [] (pack "ROUTER socket uses REQ's socket identity")

        dumpSock sink
