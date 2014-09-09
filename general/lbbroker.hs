-- |
-- Load balancing broker
-- (Clients) [REQ] >-> (frontend) ROUTER (Proxy) ROUTER (backend) >-> [REQ] (Workers)
-- |
module Main where

import System.ZMQ4.Monadic

import Control.Concurrent (threadDelay)
import Control.Monad (forM_, forever, when)
import Control.Applicative ((<$>))
import Data.ByteString.Char8 (pack, unpack)
import Text.Printf

nbrClients :: Int
nbrClients = 10

nbrWorkers :: Int
nbrWorkers = 3

workerThread :: Show a => a -> ZMQ z ()
workerThread id = do
    sock <- socket Req
    let ident = "Worker-" ++ (show id)
    setIdentity (restrict $ pack ident) sock
    connect sock "inproc://workers"
    send sock [] (pack "READY")

    forever $ do
        address <- receive sock
        receive sock -- empty frame
        receive sock >>= liftIO . printf "%s : %s\n" ident . unpack

        send sock [SendMore] address
        send sock [SendMore] (pack "")
        send sock [] (pack "OK")

clientThread :: Show a => a -> ZMQ z ()
clientThread id = do
    sock <- socket Req
    let ident = "Client-" ++ (show id)
    setIdentity (restrict $ pack ident) sock
    connect sock "inproc://clients"

    send sock [] (pack "GO")
    msg <- receive sock
    liftIO $ printf "%s : %s\n" ident (unpack msg)

processBackend :: (Receiver r, Sender s) => 
    [String] -> Int -> Socket z r -> Socket z s -> [Event] -> ZMQ z ([String], Int)
processBackend availableWorkers clientCount backend frontend events
    | In `elem` events = do
        workerId <- unpack <$> receive backend
        empty <- unpack <$> receive backend
        when (empty /= "") $ error "The second frame should be empty"

        let workerQueue = availableWorkers ++ [workerId]

        msg <- unpack <$> receive backend -- get "READY" or client reply id
        if msg == "READY"
        then -- the worker is ready; add to queue
            return (workerQueue, clientCount)
        else do -- the worker does a job; decrement client count and add to queue
            empty' <- unpack <$> receive backend
            when (empty' /= "") $ error "The fourth frame should be empty"
            -- get client msg
            reply <- receive backend
            -- send back acknowledge msg to client
            send frontend [SendMore] (pack msg)
            send frontend [SendMore] (pack "")
            send frontend [] reply
            -- mark a job done
            return (workerQueue, clientCount-1)

    | otherwise = return (availableWorkers, clientCount)

processFrontend :: (Receiver r, Sender s) =>
    [String] -> Socket z r -> Socket z s -> [Event] -> ZMQ z [String]
processFrontend availableWorkers frontend backend events
    | In `elem` events = do
        clientId <- receive frontend
        empty <- unpack <$> receive frontend
        when (empty /= "") $ error "The second frame should be empty"
        request <- receive frontend

        send backend [SendMore] (pack $ head availableWorkers)
        send backend [SendMore] (pack "")
        send backend [SendMore] clientId
        send backend [SendMore] (pack "")
        send backend [] request
        return (tail availableWorkers)

    | otherwise = return availableWorkers

lruQueue :: Socket z Router -> Socket z Router -> ZMQ z ()
lruQueue backend frontend =
    loop [] nbrClients
  where loop availableWorkers clientCount = do
        [evtsB, evtsF] <- poll (-1) [ Sock backend [In] Nothing
                                    , Sock frontend [In] Nothing]
        (availableWorkers', clientCount') <- processBackend availableWorkers clientCount backend frontend evtsB
        when (clientCount' > 0) $
            if not (null availableWorkers')
            then do
                availableWorkers'' <- processFrontend availableWorkers' frontend backend evtsF
                loop availableWorkers'' clientCount'
            else loop availableWorkers' clientCount'

main :: IO ()
main =
    runZMQ $ do
        frontend <- socket Router
        bind frontend "inproc://clients"
        backend <- socket Router
        bind backend "inproc://workers"

        forM_ [1..nbrWorkers] $ \i -> async (workerThread i)
        forM_ [1..nbrClients] $ \i -> async (clientThread i)

        lruQueue backend frontend
        liftIO $ threadDelay $ 1 * 1000 * 1000
