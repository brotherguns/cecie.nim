import asyncdispatch
import asyncnet
import posix
import strutils
import os

import "../requests"
import "./response"
import "./utils"
import "../config"
import "../savedata"
import "./object"


proc DumpSave*(cmd: ClientRequest, client: AsyncSocket, mountId: string) {.async.} =
  let dump: DumpClientRequest = cmd.dump

  var s: Stat
  if stat(dump.targetFolder.cstring, s) != 0 or not s.st_mode.S_ISDIR:
    respondWithError(client, "E:TARGET_FOLDER_INVALID-PATH=" & dump.targetFolder & "-errno=" & $errno & "(" & $strerror(errno) & ")")
    return
  let (saveDir, saveName) = getSavePathComponents(dump.saveName, SAVE_DIRECTORY)

  let saveStatus = checkSave(saveDir, saveName)
  if saveStatus != 0:
    await reportSaveError(saveStatus, client)
    return

  setupCredentials()

  let mntFolder = "/data/" & mountId
  discard rmdir(mntFolder.cstring)
  discard mkdir(mntFolder.cstring, 0o777)
  # Then dump everything
  var (errPath, handle) = mountSave(saveDir, saveName, mntFolder)
  var failed = errPath != 0
  if errPath != 0:
    respondWithError(client, "E:MOUNT_FAILED-" & errPath.toHex(2) & "-" & handle.toHex(8))
  else:
    for (kind, relativePath) in getRequiredFiles(mntFolder, dump.selectOnly):
      if kind == pcDir:
        let targetPath = joinPath(dump.targetFolder, relativePath)
        discard mkdir(targetPath.cstring, 0o777)
      elif kind == pcFile:
        let targetFile = joinPath(dump.targetFolder, relativePath)
        # Create it just in case
        let fd = open(targetFile.cstring, O_CREAT, 0o777)
        discard close(fd)
        let sourceFile = joinPath(mntFolder, relativePath)
        try:
          copyFile(sourceFile, targetFile)
        except IOError as e:
          respondWithError(client, "E:COPY_FAILED-SRC=" & sourceFile & "-DST=" & targetFile & "-" & e.msg)
          failed = true
          break
        except OSError as e:
          respondWithError(client, "E:COPY_FAILED-SRC=" & sourceFile & "-DST=" & targetFile & "-" & e.msg)
          failed = true
          break
    discard umountSave(mntFolder, handle, false)
  discard rmdir(mntFolder.cstring)
  if failed:
    exitnow(-1)
  else:
    exitnow(0)

let cmd* = Command(useSlot: true, useFork: true, fun: DumpSave)
