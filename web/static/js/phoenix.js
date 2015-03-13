let SOCKET_STATES = {connecting: 0, open: 1, closing: 2, closed: 3}

export class Channel {
  constructor(topic, message, callback, socket) {
    this.topic    = topic
    this.message  = message
    this.callback = callback
    this.socket   = socket
    this.bindings = null

    this.reset()
  }

  reset(){ this.bindings = [] }

  on(event, callback){ this.bindings.push({event, callback}) }

  isMember(topic){ return this.topic === topic }

  off(event){ this.bindings = this.bindings.filter( bind => bind.event !== event ) }

  trigger(triggerEvent, msg){
    this.bindings.filter( bind => bind.event === triggerEvent )
                 .map( bind => bind.callback(msg) )
  }

  send(event, payload){ this.socket.send({topic: this.topic, event: event, payload: payload}) }

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
  //   heartbeatIntervalMs - The millisecond interval to send a heartbeat message
  //   logger - The optional function for specialized logging, ie:
  //            `logger: (msg) -> console.log(msg)`
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
    this.reconnectAfterMs     = 5000
    this.heartbeatIntervalMs  = 30000
    this.channels             = []
    this.sendBuffer           = []

    this.transport = opts.transport || window.WebSocket || LongPoller
    this.heartbeatIntervalMs = opts.heartbeatIntervalMs || this.heartbeatIntervalMs
    this.logger = opts.logger || function(){} // noop
    this.longpoller_timeout = opts.longpoller_timeout || 20000
    this.endPoint = this.expandEndpoint(endPoint)
    this.resetBufferTimer()
  }

  protocol(){ return location.protocol.match(/^https/) ? "wss" : "ws" }

  expandEndpoint(endPoint){
    if(endPoint.charAt(0) !== "/"){ return endPoint }
    if(endPoint.charAt(1) === "/"){ return `${this.protocol()}:${endPoint}` }

    return `${this.protocol()}://${location.host}${endPoint}`
  }

  close(callback, code, reason){
    if(this.conn){
      this.conn.onclose = function(){} // noop
      if(code){ this.conn.close(code, reason || "") } else { this.conn.close() }
      this.conn = null
    }
    callback && callback()
  }

    this.close(() => {
  connect(){
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
  //    socket.onError (error) -> alert("An error occurred")
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
    this.reconnectTimer = setInterval(() => this.reconnect(), this.reconnectAfterMs)
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

  rejoinAll(){ this.channels.forEach( chan => this.rejoin(chan) ) }

  rejoin(chan){
    chan.reset()
    this.send({topic: chan.topic, event: "join", payload: chan.message})
    chan.callback(chan)
  }

  join(topic, message, callback){
    let chan = new Channel(topic, message, callback, this)
    this.channels.push(chan)
    if(this.isConnected()){ this.rejoin(chan) }
  }

  leave(topic, message = {}){
    this.send({topic: topic, event: "leave", payload: message})
    this.channels = this.channels.filter( c => !c.isMember(topic) )
  }

  send(data){
    let callback = () => this.conn.send(JSON.stringify(data))
    if(this.isConnected()){
      callback()
    }
    else {
      this.sendBuffer.push(callback)
    }
  }

  sendHeartbeat(){
    this.send({topic: "phoenix", event: "heartbeat", payload: {}})
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
      if(!resp || resp.status !== 200){ this.onerror(status) }
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
      this.xhrRequest(req, method, endPoint, accept, body, ontimeout, callback)
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
