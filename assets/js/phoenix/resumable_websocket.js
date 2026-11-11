import {
  CLOSE_SESSION_GONE,
  DEFAULT_RESUME_AFTER_MS,
  global,
  SOCKET_STATES
} from "./constants"

import Ajax from "./ajax"
import LongPoll from "./longpoll"

// how often we tell the server about the messages we received
const ACK_INTERVAL_MS = 1000
// How long we wait for the server to resume the session over a new WebSocket. It is
// shorter than the server keeps the session by default, so we can try again in time.
const RESUME_TIMEOUT_MS = 10000
// control messages are V2 messages without refs on the "phoenix" topic;
// since the socket decodes messages, we work on the encoded version - it's a bit hacky, I know
const CONTROL_PREFIX = "[null,null,\"phoenix\",\"phx_"

let control = (event, payload) => JSON.stringify([null, null, "phoenix", event, payload])

// Heartbeats and their replies are V2 messages on the "phoenix" topic with a ref but without
// join ref. They only check the current WebSocket, so neither side numbers or replays them.
const HEARTBEAT_PATTERN = /^\[null,"[^"]*","phoenix","heartbeat",/
const HEARTBEAT_REPLY_PATTERN = /^\[null,"[^"]*","phoenix","phx_reply",/
let isHeartbeat = (data, pattern) => typeof(data) === "string" && pattern.test(data)

/**
 * A WebSocket transport that resumes its session over a new WebSocket when the
 * connection fails, without rejoining channels.
 *
 * The server keeps the socket and its channels for a while after the WebSocket
 * failed, see the `:resumable` option of `Phoenix.Endpoint.socket/3`. Both sides
 * number their messages and keep them until the other side confirmed them, so
 * they send the missed ones again after resuming.
 *
 * With `longPollFallbackMs`, which the socket sets from its option of the same name,
 * we continue the session with long polling when resuming it over a WebSocket did
 * not succeed within that time, and keep long polling for the rest of the session.
 *
 * Servers that don't keep the socket for us make it behave like a WebSocket.
 */
export default class ResumableWebSocket {
  /**
   * @param {string} endPoint
   * @param {string[]} [protocols]
   * @param {Object} [opts]
   * @param {string} [opts.session] - The token of a session the server started for us,
   * which we attach to like we resume a session, see `Socket.attachSession`
   */
  constructor(endPoint, protocols, opts = {}){
    // the URL and subprotocols of a new WebSocket, which the socket replaces
    // so that we resume with its current params and auth token
    this.connectionInfo = () => ({endPoint, protocols})
    this.binaryTypeValue = "arraybuffer"
    this.resumeTimeout = RESUME_TIMEOUT_MS
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
    // the last incoming message to replay before reporting recovery
    this.replayUntil = null
    this.recoveryTimer = null
    this.retries = 0
    // how long we wait before resuming the session over a new WebSocket, which the socket sets
    this.resumeAfterMs = DEFAULT_RESUME_AFTER_MS
    this.retryTimer = null
    this.resumeTimer = null
    this.ackTimer = null
    // set once a retry failed as well, until we resumed the session
    this.interrupted = false
    // how long we try to resume the session over a WebSocket before we long poll, if at all
    this.longPollFallbackMs = null
    this.fallbackTimer = null
    // the LongPoll that continues the session once we fell back to it
    this.longpoll = null
    this.onopen = function (){ } // noop
    this.onerror = function (){ } // noop
    this.onmessage = function (){ } // noop
    this.onclose = function (){ } // noop
    this.onsuspend = function (){ } // noop
    this.onresume = function (){ } // noop
    if(opts.session){
      // we attach to the session like we resume one, and open once it resumed
      this.token = opts.session
      this.connect(true)
    } else {
      this.connect(false)
    }
  }

  get binaryType(){ return this.binaryTypeValue }

  set binaryType(binaryType){
    this.binaryTypeValue = binaryType
    if(this.ws){ this.ws.binaryType = binaryType }
  }

  get bufferedAmount(){ return this.ws ? this.ws.bufferedAmount : 0 }

  send(data){
    if(this.readyState !== SOCKET_STATES.open){ return }
    if(this.longpoll){
      this.longpoll.send(data)
      return
    }
    // we number the messages implicitly, in the order we send them
    if(!this.unsupported && !isHeartbeat(data, HEARTBEAT_PATTERN)){ this.unconfirmed.push(data) }
    if(this.ready){ this.ws.send(data) }
  }

  close(code, reason){
    if(this.readyState === SOCKET_STATES.closed){ return }
    // the server stops the session, as we did not lose the connection
    if(this.ready && this.token){ this.ws.send(control("phx_close", {})) }
    if(this.longpoll){
      const longpoll = this.longpoll
      this.longpoll = null
      longpoll.onclose = function (){ } // noop
      longpoll.close(code, reason)
    }
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
    // long polling detects failed requests itself
    if(this.longpoll){ return true }
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
    const params = resume ? {"phx:resumable": 1, "phx:resume": 1} : {"phx:resumable": 1}
    const {endPoint, protocols} = this.connectionInfo()
    const ws = new global.WebSocket(Ajax.appendParams(endPoint, params), protocols)
    ws.binaryType = this.binaryTypeValue
    this.ws = ws
    this.ready = false
    this.resuming = resume
    if(resume){
      // a server that does not answer is as good as a failed connection
      this.resumeTimer = setTimeout(() => {
        this.dropWebSocket()
        // a session we could not attach to is gone for us, so the socket connects again
        if(this.readyState === SOCKET_STATES.connecting){
          this.end()
        } else {
          this.retry()
        }
      }, this.resumeTimeout)
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
      // failed attempts to resume the session are no errors of the socket,
      // unlike failed attempts to attach to it, as we never opened
      if(this.ws === ws && (!this.token || this.readyState === SOCKET_STATES.connecting)){ this.onerror(error) }
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
    // the server starts a session with its token, which is its first message;
    // therefore if we have no token at this point it means that the server does
    // not run in resumable mode (or is outdated) - we don't need to buffer any
    // message clientside
    if(this.token === null && !this.unsupported){
      this.unsupported = true
      this.unconfirmed = []
    }
    if(!this.unsupported && isHeartbeat(data, HEARTBEAT_REPLY_PATTERN)){
      this.onmessage(event)
      return
    }
    this.received++
    this.scheduleAck()
    this.onmessage(event)
    this.scheduleRecovery()
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
        this.resumed(payload.seq, payload.last)
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
  resumed(seq, last){
    if(!this.resuming){ return }
    if(!Number.isSafeInteger(seq) || seq < this.confirmed || seq > this.confirmed + this.unconfirmed.length ||
      !Number.isSafeInteger(last) || last < this.received){
      // neither direction can have received messages the other side did not send
      this.end()
      return
    }
    clearTimeout(this.resumeTimer)
    this.confirm(seq)
    this.resuming = false
    this.ready = true
    this.replayUntil = last
    // we send the messages the server did not receive again
    this.unconfirmed.forEach(data => this.ws.send(data))
    this.retries = 0
    // The WebSocket is usable now; replay must not trigger a long-poll fallback.
    clearTimeout(this.fallbackTimer)
    this.fallbackTimer = null
    if(this.readyState === SOCKET_STATES.connecting){
      // we attached to a session the server started for us
      this.readyState = SOCKET_STATES.open
      this.onopen()
    }
    this.scheduleRecovery()
  }

  /**
   * Called in resume and after each message is received.
   * This is equivalent to awaitingMessages in Longpoll, to delay
   * onresume until all expected incoming messages are handled.
   * 
   * @private
   */
  scheduleRecovery(){
    if(this.replayUntil === null || this.received < this.replayUntil || !this.ready || this.recoveryTimer !== null){ return }
    const ws = this.ws
    // Let promises from the last replayed message settle before notifying hooks.
    this.recoveryTimer = setTimeout(() => {
      this.recoveryTimer = null
      if(this.ws !== ws || !this.ready){ return }
      this.replayUntil = null
      this.recovered()
    }, 0)
  }

  /**
   * @private
   */
  interrupt(){
    if(!this.interrupted){
      this.interrupted = true
      this.onsuspend()
    }
  }

  /**
   * @private
   */
  recovered(){
    clearTimeout(this.fallbackTimer)
    this.fallbackTimer = null
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
    this.dropWebSocket()
    clearTimeout(this.ackTimer)
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
    this.retries++
    const delay = this.resumeAfterMs(this.retries)
    // a single failed WebSocket is resumed quickly, so we only report the
    // interruption once resuming failed as well
    if(this.retries > 1){ this.interrupt() }
    if(this.readyState !== SOCKET_STATES.open){ return }
    if(this.longPollFallbackMs && !this.fallbackTimer){
      this.fallbackTimer = setTimeout(() => this.fallBack(), this.longPollFallbackMs)
    }
    this.retryTimer = setTimeout(() => {
      this.retryTimer = null
      this.connect(true)
    }, delay)
  }

  /**
   * @private
   *
   * Continues the session with long polling, as resuming it over a WebSocket did not
   * succeed in time. The LongPoll sends the messages the server did not confirm.
   */
  fallBack(){
    this.fallbackTimer = null
    if(this.readyState !== SOCKET_STATES.open){ return }
    clearTimeout(this.retryTimer)
    this.retryTimer = null
    this.dropWebSocket()
    this.resuming = false
    const {endPoint, protocols} = this.connectionInfo()
    const longpoll = new LongPoll(endPoint, protocols)
    longpoll.timeout = this.timeout
    longpoll.resumeAfterMs = this.resumeAfterMs
    longpoll.connectionInfo = this.connectionInfo
    longpoll.resumeSession({
      token: this.token,
      received: this.received,
      confirmed: this.confirmed,
      unconfirmed: this.unconfirmed
    })
    this.unconfirmed = []
    this.longpoll = longpoll
    const current = () => this.longpoll === longpoll
    longpoll.onmessage = event => { if(current()){ this.onmessage(event) } }
    longpoll.onerror = error => {
      if(!current()){ return }
      // LongPoll errors end the session. Stop reporting an open connection before
      // callbacks run, but let them close us and clean up the LongPoll themselves.
      this.readyState = SOCKET_STATES.connecting
      this.onerror(error)
    }
    longpoll.onsuspend = () => { if(current()){ this.interrupt() } }
    longpoll.onresume = () => { if(current()){ this.recovered() } }
    longpoll.onclose = event => {
      if(!current()){ return }
      // the session is gone, so the socket connects again
      this.longpoll = null
      this.stop()
      this.onclose(event)
    }
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
      this.onclose({code: CLOSE_SESSION_GONE, reason: "session_gone", wasClean: false})
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
    clearTimeout(this.recoveryTimer)
    this.recoveryTimer = null
    this.replayUntil = null
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
    clearTimeout(this.fallbackTimer)
    this.retryTimer = null
    this.ackTimer = null
    this.fallbackTimer = null
    this.interrupted = false
    this.dropWebSocket(code, reason)
  }
}
