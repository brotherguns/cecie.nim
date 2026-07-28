import posix
import asyncdispatch
import asyncnet

import "../savedata"
import "../requests"
import "./utils"
import "./object"
import "./response"

proc CreateSave*(cmd: ClientRequest, client: AsyncSocket, id: string) {.async.} =
    var s: Stat
    if stat(cmd.create.sourceFolder.cstring, s) != 0 or not s.st_mode.S_ISDIR:
        respondWithError(client, "E:TARGET_FOLDER_INVALID-PATH=" & cmd.create.sourceFolder & "-errno=" & $errno & "(" & $strerror(errno) & ")")
        return

    setupCredentials()

    var createStatus = createSave(cmd.create.sourceFolder, cmd.create.saveName, cmd.create.blocks)
    if createStatus != 0:
        respondWithError(client, "E:CREATE_FAILED-saveName=" & cmd.create.saveName & "-blocks=" & $cmd.create.blocks & "-status=" & $createStatus)
        return
    
    respondWithOk(client)

let cmd* = Command(useSlot: false, useFork: true, fun: CreateSave) 