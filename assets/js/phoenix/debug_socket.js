import {Socket} from "./socket"

export default class DebugSocket {
  constructor(path, opts = {}){
    this.socket = new Socket(path, opts)
    this.debugChannel = this.socket.channel("phoenix:debugger")
    this.debugChannel.join()
    this.logsEnabled = false
  }

  connect(){ this.socket.connect() }

  disconnect(){ this.socket.disconnect() }

  enableLogs(){ if(this.debugChannel){ return }
    this.logsEnabled = true
    this.debugChannel.on("log", ({msg, level}) => this.logsEnabled && this.log(level, msg))
  }

  disableLogs(){ this.logsEnabled = false }

  openEditor(targetNode){
    let fileLine = this.closestDebugFileLine(targetNode)
    if(fileLine){
      let [file, line] = fileLine.split(":")
      console.log(`opening ${fileLine}`)
      this.debugChannel.push("open", {file, line})
    }
  }

  // private

  log(level, str){
    let levelColor = {debug: "cyan", info: "inherit", error: "inherit"}[level]
    let consoleFunc = level === "debug" ? "info" : level
    console[consoleFunc](`%c📡 [${level}] ${str}`, `color: ${levelColor};`)
  }

  closestDebugFileLine(node){
    while(node.previousSibling){
      node = node.previousSibling
      if(node.nodeType === Node.COMMENT_NODE){
        let match = node.nodeValue.match(/.*>\s([\w\/]+.*ex:\d+)/i)
        if(match){ return match[1] }
      }
    }
    if(node.parentNode){ return this.closestDebugFileLine(node.parentNode) }
  }
}