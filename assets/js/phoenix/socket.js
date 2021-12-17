import {
  global,
  phxWindow,
  CHANNEL_EVENTS,
  DEFAULT_TIMEOUT,
  DEFAULT_VSN,
  SOCKET_STATES,
  TRANSPORTS,
  WS_CLOSE_NORMAL
} from "./constants"

import {
  closure
} from "./utils"

import Ajax from "./ajax"
import Channel from "./channel"
import LongPoll from "./longpoll"
import Serializer from "./serializer"
import Timer from "./timer"

/** Initializes the Socket *
 *
 * For IE8 support use an ES5-shim (https://github.com/es-shims/es5-shim)
 *
 * @param {string} endPoint - The string WebSocket endpoint, ie, `"ws://example.com/socket"`,
 *                                               `"wss://example.com"`
 *                                               `"/socket"` (inherited host & protocol)
 * @param {Object} [opts] - Optional configuration
 * @param {Function} [opts.transport] - The Websocket Transport, for example WebSocket or Phoenix.LongPoll.
 *
 * Defaults to WebSocket with automatic LongPoll fallback.
 * @param {Function} [opts.encode] - The function to encode outgoing messages.
 *
 * Defaults to JSON encoder.
 *
 * @param {Function} [opts.decode] - The function to decode incoming messages.
 *
 * Defaults to JSON:
 *
 * ```javascript
 * (payload, callback) => callback(JSON.parse(payload))
 * ```
 *
 * @param {number} [opts.timeout] - The default timeout in milliseconds to trigger push timeouts.
 *
 * Defaults `DEFAULT_TIMEOUT`
 * @param {number} [opts.heartbeatIntervalMs] - The millisec interval to send a heartbeat message
 * @param {number} [opts.reconnectAfterMs] - The optional function that returns the millsec
 * socket reconnect interval.
 *
 * Defaults to stepped backoff of:
 *
 * ```javascript
 * function(tries){
 *   return [10, 50, 100, 150, 200, 250, 500, 1000, 2000][tries - 1] || 5000
 * }
 * ````
 *
 * @param {number} [opts.rejoinAfterMs] - The optional function that returns the millsec
 * rejoin interval for individual channels.
 *
 * ```javascript
 * function(tries){
 *   return [1000, 2000, 5000][tries - 1] || 10000
 * }
 * ````
 *
 * @param {Function} [opts.logger] - The optional function for specialized logging, ie:
 *
 * ```javascript
 * function(kind, msg, data) {
 *   console.log(`${kind}: ${msg}`, data)
 * }
 * ```
 *
 * @param {number} [opts.longpollerTimeout] - The maximum timeout of a long poll AJAX request.
 *
 * Defaults to 20s (double the server long poll timer).
 *
 * @param {(Object|function)} [opts.params] - The optional params to pass when connecting
 * @param {string} [opts.binaryType] - The binary type to use for binary WebSocket frames.
 *
 * Defaults to "arraybuffer"
 *
 * @param {vsn} [opts.vsn] - The serializer's protocol version to send on connect.
 *
 * Defaults to DEFAULT_VSN.
*/
export default class Socket {
  constructor(endPoint, opts = {}){
    this.stateChangeCallbacks = {open: [], close: [], error: [], message: []}
    this.channels = []
    this.sendBuffer = []
    this.ref = 0
    this.timeout = opts.timeout || DEFAULT_TIMEOUT
    this.transport = opts.transport || global.WebSocket || LongPoll
    this.establishedConnections = 0
    this.defaultEncoder = Serializer.encode.bind(Serializer)
    this.defaultDecoder = Serializer.decode.bind(Serializer)
    this.closeWasClean = false
    this.binaryType = opts.binaryType || "arraybuffer"
    this.connectClock = 1
    if(this.transport !== LongPoll){
      this.encode = opts.encode || this.defaultEncoder
      this.decode = opts.decode || this.defaultDecoder
    } else {
      this.encode = this.defaultEncoder
      this.decode = this.defaultDecoder
    }
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
    }
    this.heartbeatIntervalMs = opts.heartbeatIntervalMs || 30000
    this.rejoinAfterMs = (tries) => {
      if(opts.rejoinAfterMs){
        return opts.rejoinAfterMs(tries)
      } else {
        return [1000, 2000, 5000][tries - 1] || 10000
      }
    }
    this.reconnectAfterMs = (tries) => {
      if(opts.reconnectAfterMs){
        return opts.reconnectAfterMs(tries)
      } else {
        return [10, 50, 100, 150, 200, 250, 500, 1000, 2000][tries - 1] || 5000
      }
    }
    this.logger = opts.logger || null
    this.longpollerTimeout = opts.longpollerTimeout || 20000
    this.params = closure(opts.params || {})
    this.endPoint = `${endPoint}/${TRANSPORTS.websocket}`
    this.vsn = opts.vsn || DEFAULT_VSN
    this.heartbeatTimer = null
    this.pendingHeartbeatRef = null
    this.reconnectTimer = new Timer(() => {
      this.teardown(() => this.connect())
    }, this.reconnectAfterMs)
  }

  /**
   * Disconnects and replaces the active transport
   *
   * @param {Function} newTransport - The new transport class to instantiate
   *
   */
  replaceTransport(newTransport){
    this.disconnect()
    this.transport = newTransport
  }

  /**
   * Returns the socket protocol
   *
   * @returns {string}
   */
  protocol(){ return location.protocol.match(/^https/) ? "wss" : "ws" }

  /**
   * The fully qualifed socket url
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
   * @param {Function} callback - Optional callback which is called after socket is disconnected.
   * @param {integer} code - A status code for disconnection (Optional).
   * @param {string} reason - A textual description of the reason to disconnect. (Optional)
   */
  disconnect(callback, code, reason){
    this.connectClock++
    this.closeWasClean = true
    this.reconnectTimer.reset()
    this.teardown(callback, code, reason)
  }

  /**
   *
   * @param {Object} params - The params to send when connecting, for example `{user_id: userToken}`
   *
   * Passing params to connect is deprecated; pass them in the Socket constructor instead:
   * `new Socket("/socket", {params: {user_id: userToken}})`.
   */
  connect(params){
    this.connectClock++
    if(params){
      console && console.log("passing params to connect is deprecated. Instead pass :params to the Socket constructor")
      this.params = closure(params)
    }
    if(this.conn){ return }
    this.closeWasClean = false
    this.conn = new this.transport(this.endPointURL())
    this.conn.binaryType = this.binaryType
    this.conn.timeout = this.longpollerTimeout
    this.conn.onopen = () => this.onConnOpen()
    this.conn.onerror = error => this.onConnError(error)
    this.conn.onmessage = event => this.onConnMessage(event)
    this.conn.onclose = event => this.onConnClose(event)
  }

  /**
   * Logs the message. Override `this.logger` for specialized logging. noops by default
   * @param {string} kind
   * @param {string} msg
   * @param {Object} data
   */
  log(kind, msg, data){ this.logger(kind, msg, data) }

  /**
   * Returns true if a logger has been set on this socket.
   */
  hasLogger(){ return this.logger !== null }

  /**
   * Registers callbacks for connection open events
   *
   * @example socket.onOpen(function(){ console.info("the socket was opened") })
   *
   * @param {Function} callback
   */
  onOpen(callback){
    let ref = this.makeRef()
    this.stateChangeCallbacks.open.push([ref, callback])
    return ref
  }

  /**
   * Registers callbacks for connection close events
   * @param {Function} callback
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
   * @param {Function} callback
   */
  onError(callback){
    let ref = this.makeRef()
    this.stateChangeCallbacks.error.push([ref, callback])
    return ref
  }

  /**
   * Registers callbacks for connection message events
   * @param {Function} callback
   */
  onMessage(callback){
    let ref = this.makeRef()
    this.stateChangeCallbacks.message.push([ref, callback])
    return ref
  }

  /**
   * @private
   */
  onConnOpen(){
    if(this.hasLogger()) this.log("transport", `connected to ${this.endPointURL()}`)
    this.closeWasClean = false
    this.establishedConnections++
    this.flushSendBuffer()
    this.reconnectTimer.reset()
    this.resetHeartbeat()
    this.stateChangeCallbacks.open.forEach(([, callback]) => callback())
  }

  /**
   * @private
   */

  heartbeatTimeout(){
    if(this.pendingHeartbeatRef){
      this.pendingHeartbeatRef = null
      if(this.hasLogger()){ this.log("transport", "heartbeat timeout. Attempting to re-establish connection") }
      this.abnormalClose("heartbeat timeout")
    }
  }

  resetHeartbeat(){
    if(this.conn && this.conn.skipHeartbeat){ return }
    this.pendingHeartbeatRef = null
    clearTimeout(this.heartbeatTimer)
    setTimeout(() => this.sendHeartbeat(), this.heartbeatIntervalMs)
  }

  teardown(callback, code, reason){
    if(!this.conn){
      return callback && callback()
    }

    this.waitForBufferDone(() => {
      if(this.conn){
        if(code){ this.conn.close(code, reason || "") } else { this.conn.close() }
      }

      this.waitForSocketClosed(() => {
        if(this.conn){
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

  onConnClose(event){
    let closeCode = event && event.code
    if(this.hasLogger()) this.log("transport", "close", event)
    this.triggerChanError()
    clearTimeout(this.heartbeatTimer)
    if(!this.closeWasClean && closeCode !== 1000){
      this.reconnectTimer.scheduleTimeout()
    }
    this.stateChangeCallbacks.close.forEach(([, callback]) => callback(event))
  }

  /**
   * @private
   */
  onConnError(error){
    if(this.hasLogger()) this.log("transport", error)
    let transportBefore = this.transport
    let establishedBefore = this.establishedConnections
    this.stateChangeCallbacks.error.forEach(([, callback]) => {
      callback(error, transportBefore, establishedBefore)
    })
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
   * @private
   *
   * @param {Channel}
   */
  remove(channel){
    this.off(channel.stateChangeRefs)
    this.channels = this.channels.filter(c => c.joinRef() !== channel.joinRef())
  }

  /**
   * Removes `onOpen`, `onClose`, `onError,` and `onMessage` registrations.
   *
   * @param {refs} - list of refs returned by calls to
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
   * @param {Object} chanParams - Parameters for the channel
   * @returns {Channel}
   */
  channel(topic, chanParams = {}){
    let chan = new Channel(topic, chanParams, this)
    this.channels.push(chan)
    return chan
  }

  /**
   * @param {Object} data
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
    if(this.pendingHeartbeatRef && !this.isConnected()){ return }
    this.pendingHeartbeatRef = this.makeRef()
    this.push({topic: "phoenix", event: "heartbeat", payload: {}, ref: this.pendingHeartbeatRef})
    this.heartbeatTimer = setTimeout(() => this.heartbeatTimeout(), this.heartbeatIntervalMs)
  }

  abnormalClose(reason){
    this.closeWasClean = false
    if(this.isConnected()){ this.conn.close(WS_CLOSE_NORMAL, reason) }
  }

  flushSendBuffer(){
    if(this.isConnected() && this.sendBuffer.length > 0){
      this.sendBuffer.forEach(callback => callback())
      this.sendBuffer = []
    }
  }

  onConnMessage(rawMessage){
    this.decode(rawMessage.data, msg => {
      let {topic, event, payload, ref, join_ref} = msg
      if(ref && ref === this.pendingHeartbeatRef){
        clearTimeout(this.heartbeatTimer)
        this.pendingHeartbeatRef = null
        setTimeout(() => this.sendHeartbeat(), this.heartbeatIntervalMs)
      }

      if(this.hasLogger()) this.log("receive", `${payload.status || ""} ${topic} ${event} ${ref && "(" + ref + ")" || ""}`, payload)

      for(let i = 0; i < this.channels.length; i++){
        const channel = this.channels[i]
        if(!channel.isMember(topic, event, payload, join_ref)){ continue }
        channel.trigger(event, payload, ref, join_ref)
      }

      for(let i = 0; i < this.stateChangeCallbacks.message.length; i++){
        let [, callback] = this.stateChangeCallbacks.message[i]
        callback(msg)
      }
    })
  }

  leaveOpenTopic(topic){
    let dupChannel = this.channels.find(c => c.topic === topic && (c.isJoined() || c.isJoining()))
    if(dupChannel){
      if(this.hasLogger()) this.log("transport", `leaving duplicate topic "${topic}"`)
      dupChannel.leave()
    }
  }
}
