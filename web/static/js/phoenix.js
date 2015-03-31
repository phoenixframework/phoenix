let SOCKET_STATES = {connecting: 0, open: 1, closing: 2, closed: 3}

class Push {

  // Initializes the Push
  //
  // chan - The Channel
  // event - The event, ie `"phx_join"`
  // payload - The payload, ie `{user_id: 123}`
  // mergePush - The optional `Push` to merge hooks from
  constructor(chan, event, payload, mergePush){
    this.chan         = chan
    this.event        = event
    this.payload      = payload
    this.receivedResp = null
    this.afterHooks   = []
    this.recHooks     = {}
    this.sent         = false
    if(mergePush){
      mergePush.afterHooks.forEach( hook => this.after(hook.ms, hook.callback) )
      for(var status in mergePush.recHooks){
        if(mergePush.recHooks.hasOwnProperty(status)){
          this.receive(status, mergePush.recHooks[status])
        }
      }
    }
  }

  send(){
    var ref      = this.chan.socket.makeRef()
    var refEvent = this.chan.replyEventName(ref)

    this.chan.on(refEvent, payload => {
      this.receivedResp = payload
      this.matchReceive(payload)
      this.chan.off(refEvent)
      this.cancelAfters()
    })

    this.startAfters()
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
    this.recHooks[status] = callback
    return this
  }

  after(ms, callback){
    let timer = null
    if(this.sent){ timer = setTimeout(callback, ms) }
    this.afterHooks.push({ms: ms, callback: callback, timer: timer})
    return this
  }


  // private

  matchReceive({status, response, ref}){
    let callback = this.recHooks[status]
    if(!callback){ return }

    if(this.event === "phx_join"){ callback(this.chan) } else { callback(response) }
  }

  cancelAfters(){
    this.afterHooks.forEach( hook => {
      clearTimeout(hook.timer)
      hook.timer = null
    })
  }

  startAfters(){
    this.afterHooks.map( hook => {
      if(!hook.timer){
        hook.timer = setTimeout(() => hook.callback(), hook.ms)
      }
    })
  }
}

export class Channel {
  constructor(topic, message, callback, socket) {
    this.topic      = topic
    this.message    = message
    this.callback   = callback
    this.socket     = socket
    this.bindings   = []
    this.afterHooks = []
    this.recHooks   = {}
    this.joinPush   = new Push(this, "phx_join", this.message)

    this.reset()
  }

  after(ms, callback){
    this.joinPush.after(ms, callback)
    return this
  }

  receive(status, callback){
    this.joinPush.receive(status, callback)
    return this
  }

  rejoin(){
    this.reset()
    this.joinPush.send()
  }

  onClose(callback){ this.on("phx_chan_close", callback) }

  onError(callback){
    this.on("phx_chan_error", reason => {
      callback(reason)
      this.trigger("phx_chan_close", "error")
    })
  }

  reset(){
    this.bindings = []
    let newJoinPush = new Push(this, "phx_join", this.message, this.joinPush)
    this.joinPush = newJoinPush
    // TODO rate limit this w/ timeout ?
    this.onError( reason => {
      setTimeout(() => this.rejoin(), this.socket.reconnectAfterMs)
    })
    this.on("phx_reply", payload => {
      this.trigger(this.replyEventName(payload.ref), payload)
    })
  }

  on(event, callback){ this.bindings.push({event, callback}) }

  isMember(topic){ return this.topic === topic }

  off(event){ this.bindings = this.bindings.filter( bind => bind.event !== event ) }

  trigger(triggerEvent, msg){
    this.bindings.filter( bind => bind.event === triggerEvent )
                 .map( bind => bind.callback(msg) )
  }

  push(event, payload){
    let pushEvent = new Push(this, event, payload)
    pushEvent.send()

    return pushEvent
  }

  replyEventName(ref){ return `chan_reply_${ref}` }

  leave(message = {}){
    this.socket.leave(this.topic, message)
    this.reset()
  }
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
    this.states               = SOCKET_STATES
    this.stateChangeCallbacks = {open: [], close: [], error: [], message: []}
    this.flushEveryMs         = 50
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

    this.resetBufferTimer()
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

  resetBufferTimer(){
    clearTimeout(this.sendBufferTimer)
    this.sendBufferTimer = setTimeout(() => this.flushSendBuffer(), this.flushEveryMs)
  }

  // Logs the message. Override `this.logger` for specialized logging. noops by default
  log(msg){ this.logger(msg) }

  // Registers callbacks for connection state change events
  //
  // Examples
  //
  //    socket.onError function(error){ alert("An error occurred") }
  //
  onOpen     (callback){ this.stateChangeCallbacks.open.push(callback) }
  onClose    (callback){ this.stateChangeCallbacks.close.push(callback) }
  onError    (callback){ this.stateChangeCallbacks.error.push(callback) }
  onMessage  (callback){ this.stateChangeCallbacks.message.push(callback) }

  onConnOpen(){
    clearInterval(this.reconnectTimer)
    if(!this.conn.skipHeartbeat){
      clearInterval(this.heartbeatTimer)
      this.heartbeatTimer = setInterval(() => this.sendHeartbeat(), this.heartbeatIntervalMs)
    }
    this.rejoinAll()
    this.stateChangeCallbacks.open.forEach( callback => callback() )
  }

  onConnClose(event){
    this.log("WS close:")
    this.log(event)
    clearInterval(this.reconnectTimer)
    clearInterval(this.heartbeatTimer)
    this.reconnectTimer = setInterval(() => this.connect(), this.reconnectAfterMs)
    this.stateChangeCallbacks.close.forEach( callback => callback(event) )
  }

  onConnError(error){
    this.log("WS error:")
    this.log(error)
    this.stateChangeCallbacks.error.forEach( callback => callback(error) )
  }

  connectionState(){
    switch(this.conn && this.conn.readyState){
      case this.states.connecting: return "connecting"
      case this.states.open:       return "open"
      case this.states.closing:    return "closing"
      default:                     return "closed"
    }
  }

  isConnected(){ return this.connectionState() === "open" }

  rejoinAll(){ this.channels.forEach( chan => chan.rejoin() ) }

  join(topic, message, callback){
    let chan = new Channel(topic, message, callback, this)
    this.channels.push(chan)
    if(this.isConnected()){ chan.rejoin() }
    return chan
  }

  leave(topic, message = {}){
    this.push({topic: topic, event: "phx_leave", payload: message})
    this.channels = this.channels.filter( c => !c.isMember(topic) )
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
    this.push({topic: "phoenix", event: "heartbeat", payload: {}})
  }

  flushSendBuffer(){
    if(this.isConnected() && this.sendBuffer.length > 0){
      this.sendBuffer.forEach( callback => callback() )
      this.sendBuffer = []
    }
    this.resetBufferTimer()
  }

  onConnMessage(rawMessage){
    this.log("message received:")
    this.log(rawMessage)
    let {topic, event, payload} = JSON.parse(rawMessage.data)
    this.channels.filter( chan => chan.isMember(topic) )
                 .forEach( chan => chan.trigger(event, payload) )
    this.stateChangeCallbacks.message.forEach( callback => {
      callback(topic, event, payload)
    })
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
    this.states          = SOCKET_STATES
    this.upgradeEndpoint = this.normalizeEndpoint(endPoint)
    this.pollEndpoint    = this.upgradeEndpoint + (/\/$/.test(endPoint) ? "poll" : "/poll")
    this.readyState      = this.states.connecting

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
    this.readyState = this.states.connecting
  }

  ontimeout(){
    this.onerror("timeout")
    this.closeAndRetry()
  }

  poll(){
    if(!(this.readyState === this.states.open || this.readyState === this.states.connecting)){ return }

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
          this.readyState = this.states.open
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
    this.readyState = this.states.closed
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
