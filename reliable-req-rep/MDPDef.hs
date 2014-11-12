module MDPDef (
        mdpcClient
    ,   mdpwWorker

    ,   mdpwReady
    ,   mdpwRequest
    ,   mdpwReply
    ,   mdpwHeartbeat
    ,   mdpwDisconnect

    ,   mdpsCommands
    ) where

import Data.ByteString.Char8 (empty, pack, ByteString(..))


mdpcClient = pack "MDPC01"

mdpwWorker = pack "MDPW01"

-- MDP/Server commands
mdpwReady = pack "\001"
mdpwRequest = pack "\002"
mdpwReply = pack "\003"
mdpwHeartbeat = pack "\004"
mdpwDisconnect = pack "\005"

mdpsCommands = [ empty, pack "READY", pack "REQUEST", pack "REPLY", 
                        pack "HEARTBEAT", pack "DISCONNECT" ]
