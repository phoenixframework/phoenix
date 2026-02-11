import {
  global,
  phxWindow,
  CHANNEL_EVENTS,
  DEFAULT_TIMEOUT,
  DEFAULT_VSN,
  SOCKET_STATES,
  TRANSPORTS,
  WS_CLOSE_NORMAL,
  AUTH_TOKEN_PREFIX
} from "./constants"

import {
  closure
} from "./utils"

import Ajax from "./ajax"
import Channel from "./channel"
import LongPoll from "./longpoll"
import Serializer from "./serializer"
import Timer from "./timer"

/**
* @import { Encode, Decode, Message, Vsn, SocketTransport, Params, SocketOnOpen, SocketOnClose, SocketOnError, SocketOnMessage, SocketOptions, SocketStateChangeCallbacks, HeartbeatCallback } from "./types"
*/

export default class Socket {
  /** Initializes the Socket *
   *
   * For IE8 support use an ES5-shim (https://github.com/es-shims/es5-shim)
   *
   * @constructor
   * @param {string} endPoint - The string WebSocket endpoint, ie, `"ws://example.com/socket"`,
   *                                               `"wss://example.com"`
   *                                               `"/socket"` (inherited host & protocol)
   * @param {SocketOptions} [opts] - Optional configuration
   */
  constructor(endPoint, opts = {}){
    /** @type{SocketStateChangeCallbacks} */
    this.stateChangeCallbacks = {open: [], close: [], error: [], message: []}
    /** @type{Channel[]} */
    this.channels = []
    /** @type{(() => void)[]} */
    this.sendBuffer = []
    /** @type{number} */
    this.ref = 0
    /** @type{?string} */
    this.fallbackRef = null
    /** @type{number} */
    this.timeout = opts.timeout || DEFAULT_TIMEOUT
    /** @type{SocketTransport} */
    this.transport = opts.transport || global.WebSocket || LongPoll
    /** @type{InstanceType<SocketTransport> | undefined | null} */
    this.conn = undefined
    /** @type{boolean} */
    this.primaryPassedHealthCheck = false
    /** @type{number | undefined} */
    this.longPollFallbackMs = opts.longPollFallbackMs
    /** @type{ReturnType<typeof setTimeout>} */
    this.fallbackTimer = null
    /** @type{Storage} */
    this.sessionStore = opts.sessionStorage || (global && global.sessionStorage)
    /** @type{number} */
    this.establishedConnections = 0
    /** @type{Encode<void>} */
    this.defaultEncoder = Serializer.encode.bind(Serializer)
    /** @type{Decode<void>} */
    this.defaultDecoder = Serializer.decode.bind(Serializer)
    /** @type{boolean} */
    this.closeWasClean = false
    /** @type{boolean} */
    this.disconnecting = false
    /** @type{BinaryType} */
    this.binaryType = opts.binaryType || "arraybuffer"
    /** @type{number} */
    this.connectClock = 1
    /** @type{boolean} */
    this.pageHidden = false
    /** @type{Encode<void>} */
    this.encode = undefined
    /** @type{Decode<void>} */
    this.decode = undefined
    if(this.transport !== LongPoll){
      this.encode = opts.encode || this.defaultEncoder
      this.decode = opts.decode || this.defaultDecoder
    } else {
      this.encode = this.defaultEncoder
      this.decode = this.defaultDecoder
    }
    /** @type{number | null} */
    let awaitingConnectionOnPageShow = null
    if(phxWindow && phxWindow.addEventListener){
      phxWindow.addEventListener("pagehide", _e => {
        if(this.conn){
          this.disconnect()
          awaitingConnectionOnPageShow = this.connectClock
        }
      })
      phxWindow.addEventListener("pageshow", _e => {
        if(awaitingConnectionOnPageShow === this.connectClock){
          awaitingConnectionOnPageShow = null
          this.connect()
        }
      })
      phxWindow.addEventListener("visibilitychange", () => {
        if(document.visibilityState === "hidden"){
          this.pageHidden = true
        } else {
          this.pageHidden = false
          // reconnect immediately
          if(!this.isConnected()){
            this.teardown(() => this.connect())
          }
        }
      })
    }
    /** @type{number} */
    this.heartbeatIntervalMs = opts.heartbeatIntervalMs || 30000
    /** @type{boolean} */
    this.autoSendHeartbeat = opts.autoSendHeartbeat ?? true
    /** @type{HeartbeatCallback} */
    this.heartbeatCallback = opts.heartbeatCallback ?? (() => {})
    /** @type{(tries: number) => number} */
    this.rejoinAfterMs = (tries) => {
      if(opts.rejoinAfterMs){
        return opts.rejoinAfterMs(tries)
      } else {
        return [1000, 2000, 5000][tries - 1] || 10000
      }
    }
    /** @type{(tries: number) => number} */
    this.reconnectAfterMs = (tries) => {
      if(opts.reconnectAfterMs){
        return opts.reconnectAfterMs(tries)
      } else {
        return [10, 50, 100, 150, 200, 250, 500, 1000, 2000][tries - 1] || 5000
      }
    }
    /** @type{((kind: string, msg: string, data: any) => void) | null} */
    this.logger = opts.logger || null
    if(!this.logger && opts.debug){
      this.logger = (kind, msg, data) => { console.log(`${kind}: ${msg}`, data) }
    }
    /** @type{number} */
    this.longpollerTimeout = opts.longpollerTimeout || 20000
    /** @type{() => Params} */
    this.params = closure(opts.params || {})
    /** @type{string} */
    this.endPoint = `${endPoint}/${TRANSPORTS.websocket}`
    /** @type{Vsn} */
    this.vsn = opts.vsn || DEFAULT_VSN
    /** @type{ReturnType<typeof setTimeout>} */
    this.heartbeatTimeoutTimer = null
    /** @type{ReturnType<typeof setTimeout>} */
    this.heartbeatTimer = null
    /** @type{number | null} */
    this.heartbeatSentAt = null
    /** @type{?string} */
    this.pendingHeartbeatRef = null
    /** @type{Timer} */
    this.reconnectTimer = new Timer( () => {
      if(this.pageHidden){
        this.log("Not reconnecting as page is hidden!")
        this.teardown()
        return
      }

      this.teardown(async () => {
        if(opts.beforeReconnect) await opts.beforeReconnect()
        this.connect()
      })
    }, this.reconnectAfterMs)
    /** @type{string | undefined} */
    this.authToken = opts.authToken
  }

  /**
   * Returns the LongPoll transport reference
   */
  getLongPollTransport(){ return LongPoll }

  /**
   * Disconnects and replaces the active transport
   *
   * @param {SocketTransport} newTransport - The new transport class to instantiate
   *
   */
  replaceTransport(newTransport){
    this.connectClock++
    this.closeWasClean = true
    clearTimeout(this.fallbackTimer)
    this.reconnectTimer.reset()
    if(this.conn){
      this.conn.close()
      this.conn = null
    }
    this.transport = newTransport
  }

  /**
   * Returns the socket protocol
   *
   * @returns {"wss" | "ws"}
   */
  protocol(){ return location.protocol.match(/^https/) ? "wss" : "ws" }

  /**
   * The fully qualified socket url
   *
   * @returns {string}
   */
  endPointURL(){
    let uri = Ajax.appendParams(
      Ajax.appendParams(this.endPoint, this.params()), {vsn: this.vsn})
    if(uri.charAt(0) !== "/"){ return uri }
    if(uri.charAt(1) === "/"){ return `${this.protocol()}:${uri}` }

    return `${this.protocol()}://${location.host}${uri}`
  }

  /**
   * Disconnects the socket
   *
   * See https://developer.mozilla.org/en-US/docs/Web/API/CloseEvent#Status_codes for valid status codes.
   *
   * @param {() => void} [callback] - Optional callback which is called after socket is disconnected.
   * @param {number} [code] - A status code for disconnection (Optional).
   * @param {string} [reason] - A textual description of the reason to disconnect. (Optional)
   */
  disconnect(callback, code, reason){
    this.connectClock++
    this.disconnecting = true
    this.closeWasClean = true
    clearTimeout(this.fallbackTimer)
    this.reconnectTimer.reset()
    this.teardown(() => {
      this.disconnecting = false
      callback && callback()
    }, code, reason)
  }

  /**
   * @param {Params} [params] - [DEPRECATED] The params to send when connecting, for example `{user_id: userToken}`
   *
   * Passing params to connect is deprecated; pass them in the Socket constructor instead:
   * `new Socket("/socket", {params: {user_id: userToken}})`.
   */
  connect(params){
    if(params){
      console && console.log("passing params to connect is deprecated. Instead pass :params to the Socket constructor")
      this.params = closure(params)
    }
    if(this.conn && !this.disconnecting){ return }
    if(this.longPollFallbackMs && this.transport !== LongPoll){
      this.connectWithFallback(LongPoll, this.longPollFallbackMs)
    } else {
      this.transportConnect()
    }
  }

  /**
   * Logs the message. Override `this.logger` for specialized logging. noops by default
   * @param {string} kind
   * @param {string} msg
   * @param {Object} data
   */
  log(kind, msg, data){ this.logger && this.logger(kind, msg, data) }

  /**
   * Returns true if a logger has been set on this socket.
   */
  hasLogger(){ return this.logger !== null }

  /**
   * Registers callbacks for connection open events
   *
   * @example socket.onOpen(function(){ console.info("the socket was opened") })
   *
   * @param {SocketOnOpen} callback
   */
  onOpen(callback){
    let ref = this.makeRef()
    this.stateChangeCallbacks.open.push([ref, callback])
    return ref
  }

  /**
   * Registers callbacks for connection close events
   * @param {SocketOnClose} callback
   * @returns {string}
   */
  onClose(callback){
    let ref = this.makeRef()
    this.stateChangeCallbacks.close.push([ref, callback])
    return ref
  }

  /**
   * Registers callbacks for connection error events
   *
   * @example socket.onError(function(error){ alert("An error occurred") })
   *
   * @param {SocketOnError} callback
   * @returns {string}
   */
  onError(callback){
    let ref = this.makeRef()
    this.stateChangeCallbacks.error.push([ref, callback])
    return ref
  }

  /**
   * Registers callbacks for connection message events
   * @param {SocketOnMessage} callback
   * @returns {string}
   */
  onMessage(callback){
    let ref = this.makeRef()
    this.stateChangeCallbacks.message.push([ref, callback])
    return ref
  }

  /**
   * Sets a callback that receives lifecycle events for internal heartbeat messages.
   * Useful for instrumenting connection health (e.g. sent/ok/timeout/disconnected).
   * @param {HeartbeatCallback} callback
   */
  onHeartbeat(callback){
    this.heartbeatCallback = callback
  }

  /**
   * Pings the server and invokes the callback with the RTT in milliseconds
   * @param {(timeDelta: number) => void} callback
   *
   * Returns true if the ping was pushed or false if unable to be pushed.
   */
  ping(callback){
    if(!this.isConnected()){ return false }
    let ref = this.makeRef()
    let startTime = Date.now()
    this.push({topic: "phoenix", event: "heartbeat", payload: {}, ref: ref})
    let onMsgRef = this.onMessage(msg => {
      if(msg.ref === ref){
        this.off([onMsgRef])
        callback(Date.now() - startTime)
      }
    })
    return true
  }

  /**
   * @private
   */

  transportConnect(){
    this.connectClock++
    this.closeWasClean = false
    let protocols = undefined
    // Sec-WebSocket-Protocol based token
    // (longpoll uses Authorization header instead)
    if(this.authToken){
      protocols = ["phoenix", `${AUTH_TOKEN_PREFIX}${btoa(this.authToken).replace(/=/g, "")}`]
    }
    this.conn = new this.transport(this.endPointURL(), protocols)
    this.conn.binaryType = this.binaryType
    this.conn.timeout = this.longpollerTimeout
    this.conn.onopen = () => this.onConnOpen()
    this.conn.onerror = error => this.onConnError(error)
    this.conn.onmessage = event => this.onConnMessage(event)
    this.conn.onclose = event => this.onConnClose(event)
  }

  getSession(key){ return this.sessionStore && this.sessionStore.getItem(key) }

  storeSession(key, val){ this.sessionStore && this.sessionStore.setItem(key, val) }

  connectWithFallback(fallbackTransport, fallbackThreshold = 2500){
    clearTimeout(this.fallbackTimer)
    let established = false
    let primaryTransport = true
    let openRef, errorRef
    let fallback = (reason) => {
      this.log("transport", `falling back to ${fallbackTransport.name}...`, reason)
      this.off([openRef, errorRef])
      primaryTransport = false
      this.replaceTransport(fallbackTransport)
      this.transportConnect()
    }
    if(this.getSession(`phx:fallback:${fallbackTransport.name}`)){ return fallback("memorized") }

    this.fallbackTimer = setTimeout(fallback, fallbackThreshold)

    errorRef = this.onError(reason => {
      this.log("transport", "error", reason)
      if(primaryTransport && !established){
        clearTimeout(this.fallbackTimer)
        fallback(reason)
      }
    })
    if(this.fallbackRef){
      this.off([this.fallbackRef])
    }
    this.fallbackRef = this.onOpen(() => {
      established = true
      if(!primaryTransport){
        // only memorize LP if we never connected to primary
        if(!this.primaryPassedHealthCheck){ this.storeSession(`phx:fallback:${fallbackTransport.name}`, "true") }
        return this.log("transport", `established ${fallbackTransport.name} fallback`)
      }
      // if we've established primary, give the fallback a new period to attempt ping
      clearTimeout(this.fallbackTimer)
      this.fallbackTimer = setTimeout(fallback, fallbackThreshold)
      this.ping(rtt => {
        this.log("transport", "connected to primary after", rtt)
        this.primaryPassedHealthCheck = true
        clearTimeout(this.fallbackTimer)
      })
    })
    this.transportConnect()
  }

  clearHeartbeats(){
    clearTimeout(this.heartbeatTimer)
    clearTimeout(this.heartbeatTimeoutTimer)
  }

  onConnOpen(){
    if(this.hasLogger()) this.log("transport", `connected to ${this.endPointURL()}`)
    this.closeWasClean = false
    this.disconnecting = false
    this.establishedConnections++
    this.flushSendBuffer()
    this.reconnectTimer.reset()
    if(this.autoSendHeartbeat){
      this.resetHeartbeat()
    }
    this.triggerStateCallbacks("open")
  }

  /**
   * @private
   */

  heartbeatTimeout(){
    if(this.pendingHeartbeatRef){
      this.pendingHeartbeatRef = null
      this.heartbeatSentAt = null
      if(this.hasLogger()){ this.log("transport", "heartbeat timeout. Attempting to re-establish connection") }
      try {
        this.heartbeatCallback("timeout")
      } catch (e){
        this.log("error", "error in heartbeat callback", e)
      }
      this.triggerChanError()
      this.closeWasClean = false
      this.teardown(() => this.reconnectTimer.scheduleTimeout(), WS_CLOSE_NORMAL, "heartbeat timeout")
    }
  }

  resetHeartbeat(){
    if(this.conn && this.conn.skipHeartbeat){ return }
    this.pendingHeartbeatRef = null
    this.clearHeartbeats()
    this.heartbeatTimer = setTimeout(() => this.sendHeartbeat(), this.heartbeatIntervalMs)
  }

  teardown(callback, code, reason){
    if(!this.conn){
      return callback && callback()
    }
    let connectClock = this.connectClock

    this.waitForBufferDone(() => {
      if(connectClock !== this.connectClock){ return }
      if(this.conn){
        if(code){ this.conn.close(code, reason || "") } else { this.conn.close() }
      }

      this.waitForSocketClosed(() => {
        if(connectClock !== this.connectClock){ return }
        if(this.conn){
          this.conn.onopen = function (){ } // noop
          this.conn.onerror = function (){ } // noop
          this.conn.onmessage = function (){ } // noop
          this.conn.onclose = function (){ } // noop
          this.conn = null
        }

        callback && callback()
      })
    })
  }

  waitForBufferDone(callback, tries = 1){
    if(tries === 5 || !this.conn || !this.conn.bufferedAmount){
      callback()
      return
    }

    setTimeout(() => {
      this.waitForBufferDone(callback, tries + 1)
    }, 150 * tries)
  }

  waitForSocketClosed(callback, tries = 1){
    if(tries === 5 || !this.conn || this.conn.readyState === SOCKET_STATES.closed){
      callback()
      return
    }

    setTimeout(() => {
      this.waitForSocketClosed(callback, tries + 1)
    }, 150 * tries)
  }

  /**
  * @param {CloseEvent} event
  */
  onConnClose(event){
    if(this.conn) this.conn.onclose = () => {} // noop to prevent recursive calls in teardown
    if(this.hasLogger()) this.log("transport", "close", event)
    this.triggerChanError()
    this.clearHeartbeats()
    if(!this.closeWasClean){
      this.reconnectTimer.scheduleTimeout()
    }
    this.triggerStateCallbacks("close", event)
  }

  /**
   * @private
   * @param {Event} error
   */
  onConnError(error){
    if(this.hasLogger()) this.log("transport", error)
    let transportBefore = this.transport
    let establishedBefore = this.establishedConnections
    this.triggerStateCallbacks("error", error, transportBefore, establishedBefore)
    if(transportBefore === this.transport || establishedBefore > 0){
      this.triggerChanError()
    }
  }

  /**
   * @private
   */
  triggerChanError(){
    this.channels.forEach(channel => {
      if(!(channel.isErrored() || channel.isLeaving() || channel.isClosed())){
        channel.trigger(CHANNEL_EVENTS.error)
      }
    })
  }

  /**
   * @returns {string}
   */
  connectionState(){
    switch(this.conn && this.conn.readyState){
      case SOCKET_STATES.connecting: return "connecting"
      case SOCKET_STATES.open: return "open"
      case SOCKET_STATES.closing: return "closing"
      default: return "closed"
    }
  }

  /**
   * @returns {boolean}
   */
  isConnected(){ return this.connectionState() === "open" }

  /**
   *
   * @param {Channel} channel
   */
  remove(channel){
    this.off(channel.stateChangeRefs)
    this.channels = this.channels.filter(c => c !== channel)
  }

  /**
   * Removes `onOpen`, `onClose`, `onError,` and `onMessage` registrations.
   *
   * @param {string[]} refs - list of refs returned by calls to
   *                 `onOpen`, `onClose`, `onError,` and `onMessage`
   */
  off(refs){
    for(let key in this.stateChangeCallbacks){
      this.stateChangeCallbacks[key] = this.stateChangeCallbacks[key].filter(([ref]) => {
        return refs.indexOf(ref) === -1
      })
    }
  }

  /**
   * Initiates a new channel for the given topic
   *
   * @param {string} topic
   * @param {Params | (() => Params)} [chanParams]- Parameters for the channel
   * @returns {Channel}
   */
  channel(topic, chanParams = {}){
    let chan = new Channel(topic, chanParams, this)
    this.channels.push(chan)
    return chan
  }

  /**
   * @param {Message<Record<string, any>>} data
   */
  push(data){
    if(this.hasLogger()){
      let {topic, event, payload, ref, join_ref} = data
      this.log("push", `${topic} ${event} (${join_ref}, ${ref})`, payload)
    }

    if(this.isConnected()){
      this.encode(data, result => this.conn.send(result))
    } else {
      this.sendBuffer.push(() => this.encode(data, result => this.conn.send(result)))
    }
  }

  /**
   * Return the next message ref, accounting for overflows
   * @returns {string}
   */
  makeRef(){
    let newRef = this.ref + 1
    if(newRef === this.ref){ this.ref = 0 } else { this.ref = newRef }

    return this.ref.toString()
  }

  sendHeartbeat(){
    if(!this.isConnected()){
      try {
        this.heartbeatCallback("disconnected")
      } catch (e){
        this.log("error", "error in heartbeat callback", e)
      }
      return
    }
    if(this.pendingHeartbeatRef){
      this.heartbeatTimeout()
      return
    }
    this.pendingHeartbeatRef = this.makeRef()
    this.heartbeatSentAt = Date.now()
    this.push({topic: "phoenix", event: "heartbeat", payload: {}, ref: this.pendingHeartbeatRef})
    try {
      this.heartbeatCallback("sent")
    } catch (e){
      this.log("error", "error in heartbeat callback", e)
    }
    this.heartbeatTimeoutTimer = setTimeout(() => this.heartbeatTimeout(), this.heartbeatIntervalMs)
  }

  flushSendBuffer(){
    if(this.isConnected() && this.sendBuffer.length > 0){
      this.sendBuffer.forEach(callback => callback())
      this.sendBuffer = []
    }
  }

  /**
  * @param {MessageEvent<any>} rawMessage
  */
  onConnMessage(rawMessage){
    this.decode(rawMessage.data, msg => {
      let {topic, event, payload, ref, join_ref} = msg
      if(ref && ref === this.pendingHeartbeatRef){
        const latency = this.heartbeatSentAt ? Date.now() - this.heartbeatSentAt : undefined
        this.clearHeartbeats()
        try {
          this.heartbeatCallback(payload.status === "ok" ? "ok" : "error", latency)
        } catch (e){
          this.log("error", "error in heartbeat callback", e)
        }
        this.pendingHeartbeatRef = null
        this.heartbeatSentAt = null
        if(this.autoSendHeartbeat){
          this.heartbeatTimer = setTimeout(() => this.sendHeartbeat(), this.heartbeatIntervalMs)
        }
      }

      if(this.hasLogger()) this.log("receive", `${payload.status || ""} ${topic} ${event} ${ref && "(" + ref + ")" || ""}`.trim(), payload)

      for(let i = 0; i < this.channels.length; i++){
        const channel = this.channels[i]
        if(!channel.isMember(topic, event, payload, join_ref)){ continue }
        channel.trigger(event, payload, ref, join_ref)
      }

      this.triggerStateCallbacks("message", msg)
    })
  }

  /**
   * @private
   * @template {keyof SocketStateChangeCallbacks} K
   * @param {K} event
   * @param {...Parameters<SocketStateChangeCallbacks[K][number][1]>} args
   * @returns {void}
   */
  triggerStateCallbacks(event, ...args){
    try {
      this.stateChangeCallbacks[event].forEach(([_, callback]) => {
        try {
          callback(...args)
        } catch (e){
          this.log("error", `error in ${event} callback`, e)
        }
      })
    } catch (e){
      this.log("error", `error triggering ${event} callbacks`, e)
    }
  }

  leaveOpenTopic(topic){
    let dupChannel = this.channels.find(c => c.topic === topic && (c.isJoined() || c.isJoining()))
    if(dupChannel){
      if(this.hasLogger()) this.log("transport", `leaving duplicate topic "${topic}"`)
      dupChannel.leave()
    }
  }
}
