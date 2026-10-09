import {
  SOCKET_STATES,
  TRANSPORTS,
  AUTH_TOKEN_PREFIX,
  MAX_LONGPOLL_BATCH_SIZE
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
    // the pending requests and queued messages, which are cancelled when we stop
    this.reqs = new Set()
    this.messageTimers = new Set()
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
    // we must wait for the caller to finish setting up our callbacks and timeout properties,
    // and it might close us before that, e.g. when disconnecting right after connecting
    setTimeout(() => this.poll(), 0)
  }

  normalizeEndpoint(endPoint){
    return (endPoint
      .replace("ws://", "http://")
      .replace("wss://", "https://")
      .replace(new RegExp("(.*)\/" + TRANSPORTS.websocket), "$1/" + TRANSPORTS.longpoll))
  }

  endpointURL(){
    return this.pollEndpoint
  }

  closeAndRetry(error, code, reason, wasClean){
    if(!this.isActive()){ return }
    // like a failed WebSocket, we are no longer open when we emit the error and then the close.
    // We are connecting again before their callbacks run, so that they can still close us for
    // good, e.g. when they disconnect the socket
    this.stop(SOCKET_STATES.connecting)
    this.onerror(error)
    if(this.isActive()){ this.emitClose(code, reason, wasClean) }
  }

  ontimeout(){
    this.closeAndRetry("timeout", 1005, "timeout", false)
  }

  isActive(){ return this.readyState === SOCKET_STATES.open || this.readyState === SOCKET_STATES.connecting }

  poll(){
    // onopen can close us before the next poll, just as the caller can close us
    // before the constructor's deferred first poll
    if(!this.isActive()){ return }
    const headers = {"Accept": "application/json"}
    if(this.authToken){
      headers["X-Phoenix-AuthToken"] = this.authToken
    }
    this.ajax("GET", headers, null, () => this.ontimeout(), resp => {
      if(resp){
        var {status, token, messages} = resp
        if(status === 410 && this.token !== null){
          // In case we already have a token, this means that our existing session
          // is gone. We fail so that the client rejoins its channels.
          this.closeAndRetry(410, 3410, "session_gone", false)
          return
        }
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
            //
            // We might stop before that, e.g. when a POST times out or a message
            // handler disconnects, which cancels the remaining messages.
            const timer = setTimeout(() => {
              this.messageTimers.delete(timer)
              this.onmessage({data: msg})
            }, 0)
            this.messageTimers.add(timer)
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
          this.closeAndRetry(500, 1011, "internal server error", false)
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

  batchSend(messages, offset = 0){
    this.awaitingBatchAck = true
    const next = offset + MAX_LONGPOLL_BATCH_SIZE
    const batch = messages.slice(offset, next)
    this.ajax("POST", {"Content-Type": "application/x-ndjson"}, batch.join("\n"), () => this.ontimeout(), resp => {
      if(!resp || resp.status !== 200){
        // this calls stop which already clears awaitingBatchAck
        this.closeAndRetry(resp && resp.status, 1011, "internal server error", false)
      } else if(next < messages.length){
        this.batchSend(messages, next)
      } else if(this.batchBuffer.length > 0){
        this.batchSend(this.batchBuffer)
        this.batchBuffer = []
      } else {
        this.awaitingBatchAck = false
      }
    })
  }

  close(code, reason, wasClean){
    this.stop(SOCKET_STATES.closed)
    this.emitClose(code, reason, wasClean)
  }

  /**
   * Cancels the pending requests, queued messages and outgoing batches.
   */
  stop(readyState){
    this.readyState = readyState
    // the requests are no longer ours before we abort them, as aborting can invoke their
    // callbacks, synchronously for XHR and asynchronously for fetch
    const reqs = this.reqs
    this.reqs = new Set()
    for(let {req} of reqs){ req && req.abort() }
    for(let timer of this.messageTimers){ clearTimeout(timer) }
    this.messageTimers.clear()
    this.batchBuffer = []
    this.awaitingBatchAck = false
    clearTimeout(this.currentBatchTimer)
    this.currentBatchTimer = null
    this.currentBatch = null
  }

  /**
   * Emits the close event. Like a WebSocket closed without a code, it reports 1005 (no status)
   * unless one is given, as 1000 would look like the server closing the connection normally.
   */
  emitClose(code = 1005, reason, wasClean = true){
    let opts = {code, reason, wasClean}
    if(typeof(CloseEvent) !== "undefined"){
      this.onclose(new CloseEvent("close", opts))
    } else {
      this.onclose(opts)
    }
  }

  ajax(method, headers, body, onCallerTimeout, callback){
    // the request is ours until it completes or we stop, and the callbacks of a request
    // that is not ours anymore are ignored. It is ours before it starts, as a request can
    // complete while it starts.
    const request = {req: null}
    this.reqs.add(request)
    let ontimeout = () => {
      if(this.reqs.delete(request)){ onCallerTimeout() }
    }
    if(this.token !== null){
      headers = Object.assign({}, headers, {"X-Phoenix-Longpoll-Token": this.token})
    }
    request.req = Ajax.request(method, this.endpointURL(), headers, body, this.timeout, ontimeout, resp => {
      if(this.reqs.delete(request)){ callback(resp) }
    })
  }
}
