import {
  global,
  SOCKET_STATES
} from "./constants"

import Ajax from "./ajax"

// how long we wait before resuming the session over a new WebSocket
const RETRY_DELAYS = [100, 500, 1000, 2000, 5000]
// how often we tell the server about the messages we received
const ACK_INTERVAL_MS = 1000
const DEFAULT_RESUME_TIMEOUT_MS = 10000
// control messages are V2 messages without refs on the "phoenix" topic
const CONTROL_PREFIX = "[null,null,\"phoenix\",\"phx_"

let control = (event, payload) => JSON.stringify([null, null, "phoenix", event, payload])

/**
 * A WebSocket transport that resumes its session over a new WebSocket when the
 * connection fails, without rejoining channels.
 *
 * The server keeps the socket and its channels for a while after the WebSocket
 * failed, see the `:resumable` option of `Phoenix.Endpoint.socket/3`. Both sides
 * number their messages and keep them until the other side confirmed them, so
 * they send the missed ones again after resuming.
 *
 * Servers that don't keep the socket for us make it behave like a WebSocket.
 */
export default class ResumableWebSocket {
  constructor(endPoint, protocols){
    this.endPoint = endPoint
    this.protocols = protocols
    this.binaryTypeValue = "arraybuffer"
    this.timeout = DEFAULT_RESUME_TIMEOUT_MS
    this.readyState = SOCKET_STATES.connecting
    // the token of the session, once the server told us that it keeps the socket for us
    this.token = null
    // set when the server does not keep the socket for us
    this.unsupported = false
    // the number of messages we received
    this.received = 0
    // the messages the server did not confirm yet, and the number of the last one it confirmed
    this.unconfirmed = []
    this.confirmed = 0
    this.ws = null
    // set while the WebSocket carries our messages, once it opened or the session resumed over it
    this.ready = false
    // set while we wait for the server to resume the session over the WebSocket
    this.resuming = false
    this.retries = 0
    this.retryTimer = null
    this.resumeTimer = null
    this.ackTimer = null
    // set once a retry failed as well, until we resumed the session
    this.interrupted = false
    this.onopen = function (){ } // noop
    this.onerror = function (){ } // noop
    this.onmessage = function (){ } // noop
    this.onclose = function (){ } // noop
    this.onsuspend = function (){ } // noop
    this.onresume = function (){ } // noop
    this.connect(false)
  }

  get binaryType(){ return this.binaryTypeValue }

  set binaryType(binaryType){
    this.binaryTypeValue = binaryType
    if(this.ws){ this.ws.binaryType = binaryType }
  }

  get bufferedAmount(){ return this.ws ? this.ws.bufferedAmount : 0 }

  send(data){
    if(this.readyState !== SOCKET_STATES.open){ return }
    // we number the messages implicitly, in the order we send them
    if(!this.unsupported){ this.unconfirmed.push(data) }
    if(this.ready){ this.ws.send(data) }
  }

  close(code, reason){
    if(this.readyState === SOCKET_STATES.closed){ return }
    // the server stops the session, as we did not lose the connection
    if(this.ready && this.token){ this.ws.send(control("phx_close", {})) }
    this.stop(code, reason)
    this.onclose({code: code || 1005, reason: reason || "", wasClean: true})
  }

  /**
   * @private
   *
   * Resumes the session over a new WebSocket when the heartbeat timed out, as the
   * current one is presumed dead. Returns whether we resume the session.
   */
  resumeAfterHeartbeatTimeout(){
    if(this.readyState !== SOCKET_STATES.open || !this.token){ return false }
    if(this.ws && !this.resuming){
      this.dropWebSocket()
      this.retry()
    }
    return true
  }

  /**
   * @private
   */
  connect(resume){
    const WebSocket = ResumableWebSocket.WebSocket || global.WebSocket
    const params = resume ? {resumable: 1, resume: 1} : {resumable: 1}
    const ws = new WebSocket(Ajax.appendParams(this.endPoint, params), this.protocols)
    ws.binaryType = this.binaryTypeValue
    this.ws = ws
    this.ready = false
    this.resuming = resume
    if(resume){
      // a server that does not answer is as good as a failed connection
      this.resumeTimer = setTimeout(() => {
        this.dropWebSocket()
        this.retry()
      }, this.timeout)
    }
    ws.onopen = () => {
      if(this.ws !== ws){ return }
      if(resume){
        ws.send(control("phx_resume", {token: this.token, ack: this.received}))
      } else {
        this.ready = true
        this.readyState = SOCKET_STATES.open
        this.onopen()
      }
    }
    ws.onerror = error => {
      // failed attempts to resume the session are no errors of the socket
      if(this.ws === ws && !this.token){ this.onerror(error) }
    }
    ws.onmessage = event => { if(this.ws === ws){ this.handleMessage(event) } }
    ws.onclose = event => { if(this.ws === ws){ this.handleClose(event) } }
  }

  /**
   * @private
   */
  handleMessage(event){
    const {data} = event
    if(typeof(data) === "string" && data.startsWith(CONTROL_PREFIX)){
      const [, , , name, payload] = JSON.parse(data)
      this.handleControl(name, payload)
      return
    }
    if(this.resuming){
      // an older server or a socket that is not resumable treats our resume
      // as a new connection
      this.end()
      return
    }
    // the server starts a session with its token, which is its first message
    if(this.token === null && !this.unsupported){
      this.unsupported = true
      this.unconfirmed = []
    }
    this.received++
    this.scheduleAck()
    this.onmessage(event)
  }

  /**
   * @private
   */
  handleControl(name, payload){
    switch(name){
      case "phx_session":
        this.token = payload.token
        break
      case "phx_resumed":
        this.resumed(payload.seq)
        break
      case "phx_ack":
        this.confirm(payload.seq)
        break
      case "phx_gone":
        // the session stopped with a close code, or we cannot resume it
        this.end(payload.code)
        break
      default:
        // an older server replies to our resume like to an unknown message
        if(this.resuming){ this.end() }
    }
  }

  /**
   * @private
   */
  resumed(seq){
    if(!this.resuming){ return }
    if(seq < this.confirmed || seq > this.confirmed + this.unconfirmed.length){
      // the server cannot have received messages we did not send
      this.end()
      return
    }
    clearTimeout(this.resumeTimer)
    this.confirm(seq)
    this.resuming = false
    this.ready = true
    // we send the messages the server did not receive again
    this.unconfirmed.forEach(data => this.ws.send(data))
    this.retries = 0
    if(this.interrupted){
      this.interrupted = false
      this.onresume()
    }
  }

  /**
   * @private
   */
  confirm(seq){
    if(seq > this.confirmed){
      this.unconfirmed.splice(0, seq - this.confirmed)
      this.confirmed = seq
    }
  }

  /**
   * @private
   */
  scheduleAck(){
    if(this.ackTimer || !this.token){ return }
    this.ackTimer = setTimeout(() => {
      this.ackTimer = null
      if(this.ready){ this.ws.send(control("phx_ack", {ack: this.received})) }
    }, ACK_INTERVAL_MS)
  }

  /**
   * @private
   */
  handleClose(event){
    this.ws = null
    this.ready = false
    clearTimeout(this.ackTimer)
    clearTimeout(this.resumeTimer)
    this.ackTimer = null
    if(this.readyState === SOCKET_STATES.open && this.token){
      this.retry()
    } else {
      this.stop()
      this.onclose(event)
    }
  }

  /**
   * @private
   *
   * Resumes the session over a new WebSocket with backoff.
   */
  retry(){
    this.resuming = false
    const delay = RETRY_DELAYS[Math.min(this.retries, RETRY_DELAYS.length - 1)]
    this.retries++
    // a single failed WebSocket is resumed quickly, so we only report the
    // interruption once resuming failed as well
    if(this.retries > 1 && !this.interrupted){
      this.interrupted = true
      this.onsuspend()
    }
    if(this.readyState !== SOCKET_STATES.open){ return }
    this.retryTimer = setTimeout(() => {
      this.retryTimer = null
      this.connect(true)
    }, delay)
  }

  /**
   * @private
   *
   * Closes the transport when the session is gone, so the socket connects again.
   */
  end(code){
    this.stop()
    if(code){
      this.onclose({code, reason: "", wasClean: true})
    } else {
      this.onclose({code: 3410, reason: "session_gone", wasClean: false})
    }
  }

  /**
   * @private
   */
  dropWebSocket(code, reason){
    const ws = this.ws
    this.ws = null
    this.ready = false
    clearTimeout(this.resumeTimer)
    if(!ws){ return }
    ws.onopen = ws.onerror = ws.onmessage = ws.onclose = function (){ } // noop
    if(ws.readyState === SOCKET_STATES.connecting || ws.readyState === SOCKET_STATES.open){
      if(code){ ws.close(code, reason || "") } else { ws.close() }
    }
  }

  /**
   * @private
   */
  stop(code, reason){
    this.readyState = SOCKET_STATES.closed
    clearTimeout(this.retryTimer)
    clearTimeout(this.ackTimer)
    this.retryTimer = null
    this.ackTimer = null
    this.interrupted = false
    this.dropWebSocket(code, reason)
  }
}
