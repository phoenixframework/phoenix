import {
  SOCKET_STATES,
  TRANSPORTS,
  AUTH_TOKEN_PREFIX
} from "./constants"

import Ajax from "./ajax"

let arrayBufferToBase64 = (buffer) => {
  let binary = ""
  let bytes = new Uint8Array(buffer)
  let len = bytes.byteLength
  for(let i = 0; i < len; i++){ binary += String.fromCharCode(bytes[i]) }
  return btoa(binary)
}

export default class LongPoll {

  constructor(endPoint, protocols){
    // we only support subprotocols for authToken
    // ["phoenix", "base64url.bearer.phx.BASE64_ENCODED_TOKEN"]
    if(protocols && protocols.length === 2 && protocols[1].startsWith(AUTH_TOKEN_PREFIX)){
      this.authToken = atob(protocols[1].slice(AUTH_TOKEN_PREFIX.length))
    }
    this.endPoint = null
    this.token = null
    this.skipHeartbeat = true
    this.reqs = new Set()
    this.awaitingBatchAck = false
    this.currentBatch = null
    this.currentBatchTimer = null
    this.batchBuffer = []
    this.onopen = function (){ } // noop
    this.onerror = function (){ } // noop
    this.onmessage = function (){ } // noop
    this.onclose = function (){ } // noop
    this.pollEndpoint = this.normalizeEndpoint(endPoint)
    this.readyState = SOCKET_STATES.connecting
    // we must wait for the caller to finish setting up our callbacks and timeout properties
    setTimeout(() => this.poll(), 0)
  }

  normalizeEndpoint(endPoint){
    return (endPoint
      .replace("ws://", "http://")
      .replace("wss://", "https://")
      .replace(new RegExp("(.*)\/" + TRANSPORTS.websocket), "$1/" + TRANSPORTS.longpoll))
  }

  endpointURL(){
    return Ajax.appendParams(this.pollEndpoint, {token: this.token})
  }

  closeAndRetry(code, reason, wasClean){
    this.close(code, reason, wasClean)
    this.readyState = SOCKET_STATES.connecting
  }

  ontimeout(){
    this.onerror("timeout")
    this.closeAndRetry(1005, "timeout", false)
  }

  isActive(){ return this.readyState === SOCKET_STATES.open || this.readyState === SOCKET_STATES.connecting }

  poll(){
    const headers = {"Accept": "application/json"}
    if(this.authToken){
      headers["X-Phoenix-AuthToken"] = this.authToken
    }
    this.ajax("GET", headers, null, () => this.ontimeout(), resp => {
      if(resp){
        var {status, token, messages} = resp
        this.token = token
      } else {
        status = 0
      }

      switch(status){
        case 200:
          messages.forEach(msg => {
            // Tasks are what things like event handlers, setTimeout callbacks,
            // promise resolves and more are run within.
            // In modern browsers, there are two different kinds of tasks,
            // microtasks and macrotasks.
            // Microtasks are mainly used for Promises, while macrotasks are
            // used for everything else.
            // Microtasks always have priority over macrotasks. If the JS engine
            // is looking for a task to run, it will always try to empty the
            // microtask queue before attempting to run anything from the
            // macrotask queue.
            //
            // For the WebSocket transport, messages always arrive in their own
            // event. This means that if any promises are resolved from within,
            // their callbacks will always finish execution by the time the
            // next message event handler is run.
            //
            // In order to emulate this behaviour, we need to make sure each
            // onmessage handler is run within its own macrotask.
            setTimeout(() => this.onmessage({data: msg}), 0)
          })
          this.poll()
          break
        case 204:
          this.poll()
          break
        case 410:
          this.readyState = SOCKET_STATES.open
          this.onopen({})
          this.poll()
          break
        case 403:
          this.onerror(403)
          this.close(1008, "forbidden", false)
          break
        case 0:
        case 500:
          this.onerror(500)
          this.closeAndRetry(1011, "internal server error", 500)
          break
        default: throw new Error(`unhandled poll status ${status}`)
      }
    })
  }

  // we collect all pushes within the current event loop by
  // setTimeout 0, which optimizes back-to-back procedural
  // pushes against an empty buffer

  send(body){
    if(typeof(body) !== "string"){ body = arrayBufferToBase64(body) }
    if(this.currentBatch){
      this.currentBatch.push(body)
    } else if(this.awaitingBatchAck){
      this.batchBuffer.push(body)
    } else {
      this.currentBatch = [body]
      this.currentBatchTimer = setTimeout(() => {
        this.batchSend(this.currentBatch)
        this.currentBatch = null
      }, 0)
    }
  }

  batchSend(messages){
    this.awaitingBatchAck = true
    this.ajax("POST", {"Content-Type": "application/x-ndjson"}, messages.join("\n"), () => this.onerror("timeout"), resp => {
      this.awaitingBatchAck = false
      if(!resp || resp.status !== 200){
        this.onerror(resp && resp.status)
        this.closeAndRetry(1011, "internal server error", false)
      } else if(this.batchBuffer.length > 0){
        this.batchSend(this.batchBuffer)
        this.batchBuffer = []
      }
    })
  }

  close(code, reason, wasClean){
    for(let req of this.reqs){ req.abort() }
    this.readyState = SOCKET_STATES.closed
    let opts = Object.assign({code: 1000, reason: undefined, wasClean: true}, {code, reason, wasClean})
    this.batchBuffer = []
    clearTimeout(this.currentBatchTimer)
    this.currentBatchTimer = null
    if(typeof(CloseEvent) !== "undefined"){
      this.onclose(new CloseEvent("close", opts))
    } else {
      this.onclose(opts)
    }
  }

  ajax(method, headers, body, onCallerTimeout, callback){
    let req
    let ontimeout = () => {
      this.reqs.delete(req)
      onCallerTimeout()
    }
    req = Ajax.request(method, this.endpointURL(), headers, body, this.timeout, ontimeout, resp => {
      this.reqs.delete(req)
      if(this.isActive()){ callback(resp) }
    })
    this.reqs.add(req)
  }
}
