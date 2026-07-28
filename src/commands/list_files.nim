import asyncdispatch
import asyncnet
import os
import posix
import json
import strutils

import "./utils"
import "./response"
import "../requests"
import "./object"

type ListEntry = object
  kind*: PathComponent
  path*: string
  size*: Off
  mode*: Mode
  uid*: Uid
  gid*: Gid

proc ListFiles*(cmd: ClientRequest, client: AsyncSocket, id: string) {.async.} =
  let ls : ListFilesClientRequest = cmd.ls

  let folder = ls.folder

  var folderStat : Stat
  if stat(folder.cstring, folderStat) == -1:
    respondWithError(client, "E:STAT_FAILED-PATH=" & folder & "-errno=" & $errno & "(" & $strerror(errno) & ")")
    return
  
  var listEntries: seq[ListEntry] = newSeq[ListEntry]()
  var failed = false
  for (kind, relativePath) in getRequiredFiles(folder, @[]):
    var s : Stat
    let fullPath = folder / relativePath
    if stat(fullPath.cstring, s) == -1:
      respondWithError(client, "E:STAT_FAILED-PATH=" & fullPath & "-errno=" & $errno & "(" & $strerror(errno) & ")")
      failed = true
      break
    listEntries.add ListEntry(kind: kind, path: relativePath, size: s.st_size, mode: s.st_mode, uid: s.st_uid, gid: s.st_gid)

  if not failed:
    respondWithJson(client, %listEntries)

let cmd* = Command(useSlot: false, useFork: false, fun: ListFiles)
