// Phoenix Channels JavaScript client
//
// ## Socket Connection
//
// A single connection is established to the server and
// channels are mulitplexed over the connection.
// Connect to the server using the `Socket` class:
//
//     let socket = new Socket("/ws")
//     socket.connect()
//
// The `Socket` constructor takes the mount point of the socket
// as well as options that can be found in the Socket docs,
// such as configuring the `LongPoller` transport, and heartbeat.
//
//
// ## Channels
//
// Channels are isolated, concurrent processes on the server that
// subscribe to topics and broker events between the client and server.
// To join a channel, you must provide the topic, and channel params for
// authorization. Here's an example chat room example where `"new_msg"`
// events are listened for, messages are pushed to the server, and
// the channel is joined with ok/error matches, and `after` hook:
//
//     let chan = socket.chan("rooms:123", {token: roomToken})
//     chan.on("new_msg", msg => console.log("Got message", msg) )
//     $input.onEnter( e => {
//       chan.push("new_msg", {body: e.target.val})
//           .receive("ok", (message) => console.log("created message", message) )
//           .receive("error", (reasons) => console.log("create failed", reasons) )
//           .after(10000, () => console.log("Networking issue. Still waiting...") )
//     })
//     chan.join()
//         .receive("ok", ({messages}) => console.log("catching up", messages) )
//         .receive("error", ({reason}) => console.log("failed join", reason) )
//         .after(10000, () => console.log("Networking issue. Still waiting...") )
//
//
// ## Joining
//
// Joining a channel with `chan.join(topic, params)`, binds the params to
// `chan.params`. Subsequent rejoins will send up the modified params for
// updating authorization params, or passing up last_message_id information.
// Successful joins receive an "ok" status, while unsuccessful joins
// receive "error".
//
//
// ## Pushing Messages
//
// From the prevoius example, we can see that pushing messages to the server
// can be done with `chan.push(eventName, payload)` and we can optionally
// receive responses from the push. Additionally, we can use
// `after(millsec, callback)` to abort waiting for our `receive` hooks and
// take action after some period of waiting.
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
//     chan.onError( () => console.log("there was an error!") )
//     chan.onClose( () => console.log("the channel has gone away gracefully") )
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
// `chan.leave()`
//

const SOCKET_STATES = {connecting: 0, open: 1, closing: 2, closed: 3}
const CHAN_STATES = {
  closed: "closed",
  errored: "errored",
  joined: "joined",
  joining: "joining",
}
const CHAN_EVENTS = {
  close: "phx_close",
  error: "phx_error",
  join: "phx_join",
  reply: "phx_reply",
  leave: "phx_leave"
}

class Push {

  // Initializes the Push
  //
  // chan - The Channel
  // event - The event, ie `"phx_join"`
  // payload - The payload, ie `{user_id: 123}`
  //
  constructor(chan, event, payload){
    this.chan         = chan
    this.event        = event
    this.payload      = payload || {}
    this.receivedResp = null
    this.afterHook    = null
    this.recHooks     = []
    this.sent         = false
  }

  send(){
    const ref         = this.chan.socket.makeRef()
    this.refEvent     = this.chan.replyEventName(ref)
    this.receivedResp = null
    this.sent         = false

    this.chan.on(this.refEvent, payload => {
      this.receivedResp = payload
      this.matchReceive(payload)
      this.cancelRefEvent()
      this.cancelAfter()
    })

    this.startAfter()
    this.sent = true
    this.chan.socket.push({
      topic: this.chan.topic,
      event: this.event,
      payload: this.payload,
      ref: ref
    })
  }

  receive(status, callback){
    if(this.receivedResp && this.receivedResp.status === status){
      callback(this.receivedResp.response)
    }

    this.recHooks.push({status, callback})
    return this
  }

  after(ms, callback){
    if(this.afterHook){ throw(`only a single after hook can be applied to a push`) }
    let timer = null
    if(this.sent){ timer = setTimeout(callback, ms) }
    this.afterHook = {ms: ms, callback: callback, timer: timer}
    return this
  }


  // private

  matchReceive({status, response, ref}){
    this.recHooks.filter( h => h.status === status )
                 .forEach( h => h.callback(response) )
  }

  cancelRefEvent(){ this.chan.off(this.refEvent) }

  cancelAfter(){ if(!this.afterHook){ return }
    clearTimeout(this.afterHook.timer)
    this.afterHook.timer = null
  }

  startAfter(){ if(!this.afterHook){ return }
    let callback = () => {
      this.cancelRefEvent()
      this.afterHook.callback()
    }
    this.afterHook.timer = setTimeout(callback, this.afterHook.ms)
  }
}

export class Channel {
  constructor(topic, params, socket) {
    this.state       = CHAN_STATES.closed
    this.topic       = topic
    this.params      = params || {}
    this.socket      = socket
    this.bindings    = []
    this.joinedOnce  = false
    this.joinPush    = new Push(this, CHAN_EVENTS.join, this.params)
    this.pushBuffer = []

    this.joinPush.receive("ok", () => {
      this.state = CHAN_STATES.joined
    })
    this.onClose( () => {
      this.state = CHAN_STATES.closed
      this.socket.remove(this)
    })
    this.onError( reason => {
      this.state = CHAN_STATES.errored
      setTimeout( () => this.rejoinUntilConnected(), this.socket.reconnectAfterMs)
    })
    this.on(CHAN_EVENTS.reply, (payload, ref) => {
      this.trigger(this.replyEventName(ref), payload)
    })
  }

  rejoinUntilConnected(){ if(this.state !== CHAN_STATES.errored){ return }
    if(this.socket.isConnected()){
      this.rejoin()
    } else {
      setTimeout(() => this.rejoinUntilConnected(), this.socket.reconnectAfterMs)
    }
  }

  join(){
    if(this.joinedOnce){
      throw(`tried to join mulitple times. 'join' can only be called a singe time per channel instance`)
    } else {
      this.joinedOnce = true
    }
    this.sendJoin()
    return this.joinPush
  }

  onClose(callback){ this.on(CHAN_EVENTS.close, callback) }

  onError(callback){
    this.on(CHAN_EVENTS.error, reason => callback(reason) )
  }

  on(event, callback){ this.bindings.push({event, callback}) }

  off(event){ this.bindings = this.bindings.filter( bind => bind.event !== event ) }

  canPush(){ return this.socket.isConnected() && this.state === CHAN_STATES.joined }

  push(event, payload){
    if(!this.joinedOnce){
      throw(`tried to push '${event}' to '${this.topic}' before joining. Use chan.join() before pushing events`)
    }
    let pushEvent = new Push(this, event, payload)
    if(this.canPush()){
      pushEvent.send()
    } else {
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
  //     chan.leave().receive("ok", () => alert("left!") )
  //
  leave(){
    return this.push(CHAN_EVENTS.leave).receive("ok", () => {
      this.trigger(CHAN_EVENTS.close, "leave")
    })
  }


  // private

  isMember(topic){ return this.topic === topic }

  sendJoin(){
    this.state = CHAN_STATES.joining
    this.joinPush.send()
  }

  rejoin(){
    this.sendJoin()
    this.pushBuffer.forEach( pushEvent => pushEvent.send() )
    this.pushBuffer = []
  }

  trigger(triggerEvent, payload, ref){
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
  //   transport - The Websocket Transport, ie WebSocket, Phoenix.LongPoller.
  //               Defaults to WebSocket with automatic LongPoller fallback.
  //   heartbeatIntervalMs - The millisec interval to send a heartbeat message
  //   reconnectAfterMs - The millisec interval to reconnect after connection loss
  //   logger - The optional function for specialized logging, ie:
  //            `logger: function(msg){ console.log(msg) }`
  //   longpoller_timeout - The maximum timeout of a long poll AJAX request.
  //                        Defaults to 20s (double the server long poll timer).
  //
  // For IE8 support use an ES5-shim (https://github.com/es-shims/es5-shim)
  //
  constructor(endPoint, opts = {}){
    this.stateChangeCallbacks = {open: [], close: [], error: [], message: []}
    this.reconnectTimer       = null
    this.channels             = []
    this.sendBuffer           = []
    this.ref                  = 0
    this.transport            = opts.transport || window.WebSocket || LongPoller
    this.heartbeatIntervalMs  = opts.heartbeatIntervalMs || 30000
    this.reconnectAfterMs     = opts.reconnectAfterMs || 5000
    this.logger               = opts.logger || function(){} // noop
    this.longpoller_timeout   = opts.longpoller_timeout || 20000
    this.endPoint             = this.expandEndpoint(endPoint)
  }

  protocol(){ return location.protocol.match(/^https/) ? "wss" : "ws" }

  expandEndpoint(endPoint){
    if(endPoint.charAt(0) !== "/"){ return endPoint }
    if(endPoint.charAt(1) === "/"){ return `${this.protocol()}:${endPoint}` }

    return `${this.protocol()}://${location.host}${endPoint}`
  }

  disconnect(callback, code, reason){
    if(this.conn){
      this.conn.onclose = function(){} // noop
      if(code){ this.conn.close(code, reason || "") } else { this.conn.close() }
      this.conn = null
    }
    callback && callback()
  }

  connect(){
    this.disconnect(() => {
      this.conn = new this.transport(this.endPoint)
      this.conn.timeout   = this.longpoller_timeout
      this.conn.onopen    = () => this.onConnOpen()
      this.conn.onerror   = error => this.onConnError(error)
      this.conn.onmessage = event => this.onConnMessage(event)
      this.conn.onclose   = event => this.onConnClose(event)
    })
  }

  // Logs the message. Override `this.logger` for specialized logging. noops by default
  log(msg){ this.logger(msg) }

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
    this.flushSendBuffer()
    clearInterval(this.reconnectTimer)
    if(!this.conn.skipHeartbeat){
      clearInterval(this.heartbeatTimer)
      this.heartbeatTimer = setInterval(() => this.sendHeartbeat(), this.heartbeatIntervalMs)
    }
    this.stateChangeCallbacks.open.forEach( callback => callback() )
  }

  onConnClose(event){
    this.log("WS close:")
    this.log(event)
    this.triggerChanError()
    clearInterval(this.reconnectTimer)
    clearInterval(this.heartbeatTimer)
    this.reconnectTimer = setInterval(() => this.connect(), this.reconnectAfterMs)
    this.stateChangeCallbacks.close.forEach( callback => callback(event) )
  }

  onConnError(error){
    this.log("WS error:")
    this.log(error)
    this.triggerChanError()
    this.stateChangeCallbacks.error.forEach( callback => callback(error) )
  }

  triggerChanError(){
    this.channels.forEach( chan => chan.trigger(CHAN_EVENTS.error) )
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

  remove(chan){
    this.channels = this.channels.filter( c => !c.isMember(chan.topic) )
  }

  chan(topic, params){
    let chan = new Channel(topic, params, this)
    this.channels.push(chan)
    return chan
  }

  push(data){
    let callback = () => this.conn.send(JSON.stringify(data))
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

  sendHeartbeat(){
    this.push({topic: "phoenix", event: "heartbeat", payload: {}, ref: this.makeRef()})
  }

  flushSendBuffer(){
    if(this.isConnected() && this.sendBuffer.length > 0){
      this.sendBuffer.forEach( callback => callback() )
      this.sendBuffer = []
    }
  }

  onConnMessage(rawMessage){
    this.log("message received:")
    this.log(rawMessage)
    let msg = JSON.parse(rawMessage.data)
    let {topic, event, payload, ref} = msg
    this.channels.filter( chan => chan.isMember(topic) )
                 .forEach( chan => chan.trigger(event, payload, ref) )
    this.stateChangeCallbacks.message.forEach( callback => callback(msg) )
  }
}


export class LongPoller {

  constructor(endPoint){
    this.retryInMs       = 5000
    this.endPoint        = null
    this.token           = null
    this.sig             = null
    this.skipHeartbeat   = true
    this.onopen          = function(){} // noop
    this.onerror         = function(){} // noop
    this.onmessage       = function(){} // noop
    this.onclose         = function(){} // noop
    this.upgradeEndpoint = this.normalizeEndpoint(endPoint)
    this.pollEndpoint    = this.upgradeEndpoint + (/\/$/.test(endPoint) ? "poll" : "/poll")
    this.readyState      = SOCKET_STATES.connecting

    this.poll()
  }

  normalizeEndpoint(endPoint){
    return endPoint.replace("ws://", "http://").replace("wss://", "https://")
  }

  endpointURL(){
    return this.pollEndpoint + `?token=${encodeURIComponent(this.token)}&sig=${encodeURIComponent(this.sig)}`
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
        var {status, token, sig, messages} = resp
        this.token = token
        this.sig = sig
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
}

Ajax.states = {complete: 4}
