// Phoenix Channels JavaScript client
//
// ## Socket Connection
//
// A single connection is established to the server and
// channels are mulitplexed over the connection.
// Connect to the server using the `Socket` class:
//
//     let socket = new Socket("/ws", {params: {userToken: "123"}})
//     socket.connect()
//
// The `Socket` constructor takes the mount point of the socket,
// the authentication params, as well as options that can be found in
// the Socket docs, such as configuring the `LongPoll` transport, and
// heartbeat.
//
// ## Channels
//
// Channels are isolated, concurrent processes on the server that
// subscribe to topics and broker events between the client and server.
// To join a channel, you must provide the topic, and channel params for
// authorization. Here's an example chat room example where `"new_msg"`
// events are listened for, messages are pushed to the server, and
// the channel is joined with ok/error/timeout matches:
//
//     let channel = socket.channel("rooms:123", {token: roomToken})
//     channel.on("new_msg", msg => console.log("Got message", msg) )
//     $input.onEnter( e => {
//       channel.push("new_msg", {body: e.target.val}, 10000)
//        .receive("ok", (msg) => console.log("created message", msg) )
//        .receive("error", (reasons) => console.log("create failed", reasons) )
//        .receive("timeout", () => console.log("Networking issue...") )
//     })
//     channel.join()
//       .receive("ok", ({messages}) => console.log("catching up", messages) )
//       .receive("error", ({reason}) => console.log("failed join", reason) )
//       .receive("timeout", () => console.log("Networking issue. Still waiting...") )
//
//
// ## Joining
//
// Creating a channel with `socket.channel(topic, params)`, binds the params to
// `channel.params`, which are sent up on `channel.join()`.
// Subsequent rejoins will send up the modified params for
// updating authorization params, or passing up last_message_id information.
// Successful joins receive an "ok" status, while unsuccessful joins
// receive "error".
//
//
// ## Pushing Messages
//
// From the previous example, we can see that pushing messages to the server
// can be done with `channel.push(eventName, payload)` and we can optionally
// receive responses from the push. Additionally, we can use
// `receive("timeout", callback)` to abort waiting for our other `receive` hooks
//  and take action after some period of waiting. The default timeout is 5000ms.
//
//
// ## Socket Hooks
//
// Lifecycle events of the multiplexed connection can be hooked into via
// `socket.onError()` and `socket.onClose()` events, ie:
//
//     socket.onError( () => console.log("there was an error with the connection!") )
//     socket.onClose( () => console.log("the connection dropped") )
//
//
// ## Channel Hooks
//
// For each joined channel, you can bind to `onError` and `onClose` events
// to monitor the channel lifecycle, ie:
//
//     channel.onError( () => console.log("there was an error!") )
//     channel.onClose( () => console.log("the channel has gone away gracefully") )
//
// ### onError hooks
//
// `onError` hooks are invoked if the socket connection drops, or the channel
// crashes on the server. In either case, a channel rejoin is attemtped
// automatically in an exponential backoff manner.
//
// ### onClose hooks
//
// `onClose` hooks are invoked only in two cases. 1) the channel explicitly
// closed on the server, or 2). The client explicitly closed, by calling
// `channel.leave()`
//

const VSN = "1.0.0"
const SOCKET_STATES = {connecting: 0, open: 1, closing: 2, closed: 3}
const DEFAULT_TIMEOUT = 10000
const CHANNEL_STATES = {
  closed: "closed",
  errored: "errored",
  joined: "joined",
  joining: "joining",
}
const CHANNEL_EVENTS = {
  close: "phx_close",
  error: "phx_error",
  join: "phx_join",
  reply: "phx_reply",
  leave: "phx_leave"
}
const TRANSPORTS = {
  longpoll: "longpoll",
  websocket: "websocket"
}

class Push {

  // Initializes the Push
  //
  // channel - The Channel
  // event - The event, for example `"phx_join"`
  // payload - The payload, for example `{user_id: 123}`
  // timeout - The push timeout in milliseconds
  //
  constructor(channel, event, payload, timeout){
    this.channel      = channel
    this.event        = event
    this.payload      = payload || {}
    this.receivedResp = null
    this.timeout      = timeout
    this.timeoutTimer = null
    this.recHooks     = []
    this.sent         = false
  }

  resend(timeout){
    this.timeout = timeout
    this.cancelRefEvent()
    this.ref          = null
    this.refEvent     = null
    this.receivedResp = null
    this.sent         = false
    this.send()
  }

  send(){ if(this.hasReceived("timeout")){ return }
    this.startTimeout()
    this.sent = true
    this.channel.socket.push({
      topic: this.channel.topic,
      event: this.event,
      payload: this.payload,
      ref: this.ref
    })
  }

  receive(status, callback){
    if(this.hasReceived(status)){
      callback(this.receivedResp.response)
    }

    this.recHooks.push({status, callback})
    return this
  }


  // private

  matchReceive({status, response, ref}){
    this.recHooks.filter( h => h.status === status )
                 .forEach( h => h.callback(response) )
  }

  cancelRefEvent(){ if(!this.refEvent){ return }
    this.channel.off(this.refEvent)
  }

  cancelTimeout(){
    clearTimeout(this.timeoutTimer)
    this.timeoutTimer = null
  }

  startTimeout(){ if(this.timeoutTimer){ return }
    this.ref      = this.channel.socket.makeRef()
    this.refEvent = this.channel.replyEventName(this.ref)

    this.channel.on(this.refEvent, payload => {
      this.cancelRefEvent()
      this.cancelTimeout()
      this.receivedResp = payload
      this.matchReceive(payload)
    })

    this.timeoutTimer = setTimeout(() => {
      this.trigger("timeout", {})
    }, this.timeout)
  }

  hasReceived(status){
    return this.receivedResp && this.receivedResp.status === status
  }

  trigger(status, response){
    this.channel.trigger(this.refEvent, {status, response})
  }
}

export class Channel {
  constructor(topic, params, socket) {
    this.state       = CHANNEL_STATES.closed
    this.topic       = topic
    this.params      = params || {}
    this.socket      = socket
    this.bindings    = []
    this.timeout     = this.socket.timeout
    this.joinedOnce  = false
    this.joinPush    = new Push(this, CHANNEL_EVENTS.join, this.params, this.timeout)
    this.pushBuffer  = []
    this.rejoinTimer  = new Timer(
      () => this.rejoinUntilConnected(),
      this.socket.reconnectAfterMs
    )
    this.joinPush.receive("ok", () => {
      this.state = CHANNEL_STATES.joined
      this.rejoinTimer.reset()
      this.pushBuffer.forEach( pushEvent => pushEvent.send() )
      this.pushBuffer = []
    })
    this.onClose( () => {
      this.socket.log("channel", `close ${this.topic}`)
      this.state = CHANNEL_STATES.closed
      this.socket.remove(this)
    })
    this.onError( reason => {
      this.socket.log("channel", `error ${this.topic}`, reason)
      this.state = CHANNEL_STATES.errored
      this.rejoinTimer.scheduleTimeout()
    })
    this.joinPush.receive("timeout", () => {
      if(this.state !== CHANNEL_STATES.joining){ return }

      this.socket.log("channel", `timeout ${this.topic}`, this.joinPush.timeout)
      this.state = CHANNEL_STATES.errored
      this.rejoinTimer.scheduleTimeout()
    })
    this.on(CHANNEL_EVENTS.reply, (payload, ref) => {
      this.trigger(this.replyEventName(ref), payload)
    })
  }

  rejoinUntilConnected(){
    this.rejoinTimer.scheduleTimeout()
    if(this.socket.isConnected()){
      this.rejoin()
    }
  }

  join(timeout = this.timeout){
    if(this.joinedOnce){
      throw(`tried to join multiple times. 'join' can only be called a single time per channel instance`)
    } else {
      this.joinedOnce = true
    }
    this.rejoin(timeout)
    return this.joinPush
  }

  onClose(callback){ this.on(CHANNEL_EVENTS.close, callback) }

  onError(callback){
    this.on(CHANNEL_EVENTS.error, reason => callback(reason) )
  }

  on(event, callback){ this.bindings.push({event, callback}) }

  off(event){ this.bindings = this.bindings.filter( bind => bind.event !== event ) }

  canPush(){ return this.socket.isConnected() && this.state === CHANNEL_STATES.joined }

  push(event, payload, timeout = this.timeout){
    if(!this.joinedOnce){
      throw(`tried to push '${event}' to '${this.topic}' before joining. Use channel.join() before pushing events`)
    }
    let pushEvent = new Push(this, event, payload, timeout)
    if(this.canPush()){
      pushEvent.send()
    } else {
      pushEvent.startTimeout()
      this.pushBuffer.push(pushEvent)
    }

    return pushEvent
  }

  // Leaves the channel
  //
  // Unsubscribes from server events, and
  // instructs channel to terminate on server
  //
  // Triggers onClose() hooks
  //
  // To receive leave acknowledgements, use the a `receive`
  // hook to bind to the server ack, ie:
  //
  //     channel.leave().receive("ok", () => alert("left!") )
  //
  leave(timeout = this.timeout){
    let onClose = () => {
      this.socket.log("channel", `leave ${this.topic}`)
      this.trigger(CHANNEL_EVENTS.close, "leave")
    }
    let leavePush = new Push(this, CHANNEL_EVENTS.leave, {}, timeout)
    leavePush.receive("ok", () => onClose() )
             .receive("timeout", () => onClose() )
    leavePush.send()
    if(!this.canPush()){ leavePush.trigger("ok", {}) }

    return leavePush
  }

  // Overridable message hook
  //
  // Receives all events for specialized message handling
  onMessage(event, payload, ref){}

  // private

  isMember(topic){ return this.topic === topic }

  sendJoin(timeout){
    this.state = CHANNEL_STATES.joining
    this.joinPush.resend(timeout)
  }

  rejoin(timeout = this.timeout){ this.sendJoin(timeout) }

  trigger(triggerEvent, payload, ref){
    this.onMessage(triggerEvent, payload, ref)
    this.bindings.filter( bind => bind.event === triggerEvent )
                 .map( bind => bind.callback(payload, ref) )
  }

  replyEventName(ref){ return `chan_reply_${ref}` }
}

export class Socket {

  // Initializes the Socket
  //
  // endPoint - The string WebSocket endpoint, ie, "ws://example.com/ws",
  //                                               "wss://example.com"
  //                                               "/ws" (inherited host & protocol)
  // opts - Optional configuration
  //   transport - The Websocket Transport, for example WebSocket or Phoenix.LongPoll.
  //               Defaults to WebSocket with automatic LongPoll fallback.
  //   timeout - The default timeout in milliseconds to trigger push timeouts.
  //             Defaults `DEFAULT_TIMEOUT`
  //   heartbeatIntervalMs - The millisec interval to send a heartbeat message
  //   reconnectAfterMs - The optional function that returns the millsec
  //                      reconnect interval. Defaults to stepped backoff of:
  //
  //     function(tries){
  //       return [1000, 5000, 10000][tries - 1] || 10000
  //     }
  //
  //   logger - The optional function for specialized logging, ie:
  //     `logger: (kind, msg, data) => { console.log(`${kind}: ${msg}`, data) }
  //
  //   longpollerTimeout - The maximum timeout of a long poll AJAX request.
  //                        Defaults to 20s (double the server long poll timer).
  //
  //   params - The optional params to pass when connecting
  //
  // For IE8 support use an ES5-shim (https://github.com/es-shims/es5-shim)
  //
  constructor(endPoint, opts = {}){
    this.stateChangeCallbacks = {open: [], close: [], error: [], message: []}
    this.channels             = []
    this.sendBuffer           = []
    this.ref                  = 0
    this.timeout              = opts.timeout || DEFAULT_TIMEOUT
    this.transport            = opts.transport || window.WebSocket || LongPoll
    this.heartbeatIntervalMs  = opts.heartbeatIntervalMs || 30000
    this.reconnectAfterMs     = opts.reconnectAfterMs || function(tries){
      return [1000, 2000, 5000, 10000][tries - 1] || 10000
    }
    this.logger               = opts.logger || function(){} // noop
    this.longpollerTimeout    = opts.longpollerTimeout || 20000
    this.params               = opts.params || {}
    this.endPoint             = `${endPoint}/${TRANSPORTS.websocket}`
    this.reconnectTimer       = new Timer(() => {
      this.disconnect(() => this.connect())
    }, this.reconnectAfterMs)
  }

  protocol(){ return location.protocol.match(/^https/) ? "wss" : "ws" }

  endPointURL(){
    let uri = Ajax.appendParams(
      Ajax.appendParams(this.endPoint, this.params), {vsn: VSN})
    if(uri.charAt(0) !== "/"){ return uri }
    if(uri.charAt(1) === "/"){ return `${this.protocol()}:${uri}` }

    return `${this.protocol()}://${location.host}${uri}`
  }

  disconnect(callback, code, reason){
    if(this.conn){
      this.conn.onclose = function(){} // noop
      if(code){ this.conn.close(code, reason || "") } else { this.conn.close() }
      this.conn = null
    }
    callback && callback()
  }

  // params - The params to send when connecting, for example `{user_id: userToken}`
  connect(params){
    if(params){
      console && console.log("passing params to connect is deprecated. Instead pass :params to the Socket constructor")
      this.params = params
    }
    if(this.conn){ return }

    this.conn = new this.transport(this.endPointURL())
    this.conn.timeout   = this.longpollerTimeout
    this.conn.onopen    = () => this.onConnOpen()
    this.conn.onerror   = error => this.onConnError(error)
    this.conn.onmessage = event => this.onConnMessage(event)
    this.conn.onclose   = event => this.onConnClose(event)
  }

  // Logs the message. Override `this.logger` for specialized logging. noops by default
  log(kind, msg, data){ this.logger(kind, msg, data) }

  // Registers callbacks for connection state change events
  //
  // Examples
  //
  //    socket.onError(function(error){ alert("An error occurred") })
  //
  onOpen     (callback){ this.stateChangeCallbacks.open.push(callback) }
  onClose    (callback){ this.stateChangeCallbacks.close.push(callback) }
  onError    (callback){ this.stateChangeCallbacks.error.push(callback) }
  onMessage  (callback){ this.stateChangeCallbacks.message.push(callback) }

  onConnOpen(){
    this.log("transport", `connected to ${this.endPointURL()}`, this.transport.prototype)
    this.flushSendBuffer()
    this.reconnectTimer.reset()
    if(!this.conn.skipHeartbeat){
      clearInterval(this.heartbeatTimer)
      this.heartbeatTimer = setInterval(() => this.sendHeartbeat(), this.heartbeatIntervalMs)
    }
    this.stateChangeCallbacks.open.forEach( callback => callback() )
  }

  onConnClose(event){
    this.log("transport", "close", event)
    this.triggerChanError()
    clearInterval(this.heartbeatTimer)
    this.reconnectTimer.scheduleTimeout()
    this.stateChangeCallbacks.close.forEach( callback => callback(event) )
  }

  onConnError(error){
    this.log("transport", error)
    this.triggerChanError()
    this.stateChangeCallbacks.error.forEach( callback => callback(error) )
  }

  triggerChanError(){
    this.channels.forEach( channel => channel.trigger(CHANNEL_EVENTS.error) )
  }

  connectionState(){
    switch(this.conn && this.conn.readyState){
      case SOCKET_STATES.connecting: return "connecting"
      case SOCKET_STATES.open:       return "open"
      case SOCKET_STATES.closing:    return "closing"
      default:                       return "closed"
    }
  }

  isConnected(){ return this.connectionState() === "open" }

  remove(channel){
    this.channels = this.channels.filter( c => !c.isMember(channel.topic) )
  }

  channel(topic, chanParams = {}){
    let chan = new Channel(topic, chanParams, this)
    this.channels.push(chan)
    return chan
  }

  push(data){
    let {topic, event, payload, ref} = data
    let callback = () => this.conn.send(JSON.stringify(data))
    this.log("push", `${topic} ${event} (${ref})`, payload)
    if(this.isConnected()){
      callback()
    }
    else {
      this.sendBuffer.push(callback)
    }
  }

  // Return the next message ref, accounting for overflows
  makeRef(){
    let newRef = this.ref + 1
    if(newRef === this.ref){ this.ref = 0 } else { this.ref = newRef }

    return this.ref.toString()
  }

  sendHeartbeat(){ if(!this.isConnected()){ return }
    this.push({topic: "phoenix", event: "heartbeat", payload: {}, ref: this.makeRef()})
  }

  flushSendBuffer(){
    if(this.isConnected() && this.sendBuffer.length > 0){
      this.sendBuffer.forEach( callback => callback() )
      this.sendBuffer = []
    }
  }

  onConnMessage(rawMessage){
    let msg = JSON.parse(rawMessage.data)
    let {topic, event, payload, ref} = msg
    this.log("receive", `${payload.status || ""} ${topic} ${event} ${ref && "(" + ref + ")" || ""}`, payload)
    this.channels.filter( channel => channel.isMember(topic) )
                 .forEach( channel => channel.trigger(event, payload, ref) )
    this.stateChangeCallbacks.message.forEach( callback => callback(msg) )
  }
}


export class LongPoll {

  constructor(endPoint){
    this.endPoint        = null
    this.token           = null
    this.skipHeartbeat   = true
    this.onopen          = function(){} // noop
    this.onerror         = function(){} // noop
    this.onmessage       = function(){} // noop
    this.onclose         = function(){} // noop
    this.pollEndpoint    = this.normalizeEndpoint(endPoint)
    this.readyState      = SOCKET_STATES.connecting

    this.poll()
  }

  normalizeEndpoint(endPoint){
    return(endPoint
      .replace("ws://", "http://")
      .replace("wss://", "https://")
      .replace(new RegExp("(.*)\/" + TRANSPORTS.websocket), "$1/" + TRANSPORTS.longpoll))
  }

  endpointURL(){
    return Ajax.appendParams(this.pollEndpoint, {token: this.token})
  }

  closeAndRetry(){
    this.close()
    this.readyState = SOCKET_STATES.connecting
  }

  ontimeout(){
    this.onerror("timeout")
    this.closeAndRetry()
  }

  poll(){
    if(!(this.readyState === SOCKET_STATES.open || this.readyState === SOCKET_STATES.connecting)){ return }

    Ajax.request("GET", this.endpointURL(), "application/json", null, this.timeout, this.ontimeout.bind(this), (resp) => {
      if(resp){
        var {status, token, messages} = resp
        this.token = token
      } else{
        var status = 0
      }

      switch(status){
        case 200:
          messages.forEach( msg => this.onmessage({data: JSON.stringify(msg)}) )
          this.poll()
          break
        case 204:
          this.poll()
          break
        case 410:
          this.readyState = SOCKET_STATES.open
          this.onopen()
          this.poll()
          break
        case 0:
        case 500:
          this.onerror()
          this.closeAndRetry()
          break
        default: throw(`unhandled poll status ${status}`)
      }
    })
  }

  send(body){
    Ajax.request("POST", this.endpointURL(), "application/json", body, this.timeout, this.onerror.bind(this, "timeout"), (resp) => {
      if(!resp || resp.status !== 200){
        this.onerror(status)
        this.closeAndRetry()
      }
    })
  }

  close(code, reason){
    this.readyState = SOCKET_STATES.closed
    this.onclose()
  }
}


export class Ajax {

  static request(method, endPoint, accept, body, timeout, ontimeout, callback){
    if(window.XDomainRequest){
      let req = new XDomainRequest() // IE8, IE9
      this.xdomainRequest(req, method, endPoint, body, timeout, ontimeout, callback)
    } else {
      let req = window.XMLHttpRequest ?
                  new XMLHttpRequest() : // IE7+, Firefox, Chrome, Opera, Safari
                  new ActiveXObject("Microsoft.XMLHTTP") // IE6, IE5
      this.xhrRequest(req, method, endPoint, accept, body, timeout, ontimeout, callback)
    }
  }

  static xdomainRequest(req, method, endPoint, body, timeout, ontimeout, callback){
    req.timeout = timeout
    req.open(method, endPoint)
    req.onload = () => {
      let response = this.parseJSON(req.responseText)
      callback && callback(response)
    }
    if(ontimeout){ req.ontimeout = ontimeout }

    // Work around bug in IE9 that requires an attached onprogress handler
    req.onprogress = () => {}

    req.send(body)
  }

  static xhrRequest(req, method, endPoint, accept, body, timeout, ontimeout, callback){
    req.timeout = timeout
    req.open(method, endPoint, true)
    req.setRequestHeader("Content-Type", accept)
    req.onerror = () => { callback && callback(null) }
    req.onreadystatechange = () => {
      if(req.readyState === this.states.complete && callback){
        let response = this.parseJSON(req.responseText)
        callback(response)
      }
    }
    if(ontimeout){ req.ontimeout = ontimeout }

    req.send(body)
  }

  static parseJSON(resp){
    return (resp && resp !== "") ?
             JSON.parse(resp) :
             null
  }

  static serialize(obj, parentKey){
    let queryStr = [];
    for(var key in obj){ if(!obj.hasOwnProperty(key)){ continue }
      let paramKey = parentKey ? `${parentKey}[${key}]` : key
      let paramVal = obj[key]
      if(typeof paramVal === "object"){
        queryStr.push(this.serialize(paramVal, paramKey))
      } else {
        queryStr.push(encodeURIComponent(paramKey) + "=" + encodeURIComponent(paramVal))
      }
    }
    return queryStr.join("&")
  }

  static appendParams(url, params){
    if(Object.keys(params).length === 0){ return url }

    let prefix = url.match(/\?/) ? "&" : "?"
    return `${url}${prefix}${this.serialize(params)}`
  }
}

Ajax.states = {complete: 4}


// Creates a timer that accepts a `timerCalc` function to perform
// calculated timeout retries, such as exponential backoff.
//
// ## Examples
//
//    let reconnectTimer = new Timer(() => this.connect(), function(tries){
//      return [1000, 5000, 10000][tries - 1] || 10000
//    })
//    reconnectTimer.scheduleTimeout() // fires after 1000
//    reconnectTimer.scheduleTimeout() // fires after 5000
//    reconnectTimer.reset()
//    reconnectTimer.scheduleTimeout() // fires after 1000
//
class Timer {
  constructor(callback, timerCalc){
    this.callback  = callback
    this.timerCalc = timerCalc
    this.timer     = null
    this.tries     = 0
  }

  reset(){
    this.tries = 0
    clearTimeout(this.timer)
  }

  // Cancels any previous scheduleTimeout and schedules callback
  scheduleTimeout(){
    clearTimeout(this.timer)

    this.timer = setTimeout(() => {
      this.tries = this.tries + 1
      this.callback()
    }, this.timerCalc(this.tries + 1))
  }
}
