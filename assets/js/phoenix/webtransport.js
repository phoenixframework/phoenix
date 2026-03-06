import {
  global,
  SOCKET_STATES,
  TRANSPORTS,
  AUTH_TOKEN_PREFIX
} from "./constants"

const HEADER_SIZE = 5
const TEXT_FRAME_TYPE = 0
const MAX_FRAME_SIZE = 16_777_216

let appendBuffer = (left, right) => {
  let merged = new Uint8Array(left.byteLength + right.byteLength)
  merged.set(left, 0)
  merged.set(right, left.byteLength)
  return merged
}

let encodeText = (text) => {
  if(typeof (TextEncoder) !== "undefined"){
    return new TextEncoder().encode(text)
  }

  let encoded = unescape(encodeURIComponent(text))
  let bytes = new Uint8Array(encoded.length)
  for(let i = 0; i < encoded.length; i++){ bytes[i] = encoded.charCodeAt(i) }
  return bytes
}

let decodeText = (bytes) => {
  if(typeof (TextDecoder) !== "undefined"){
    return new TextDecoder().decode(bytes)
  }

  let encoded = ""
  for(let i = 0; i < bytes.length; i++){ encoded += String.fromCharCode(bytes[i]) }
  return decodeURIComponent(escape(encoded))
}

export default class WebTransport {
  constructor(endPoint, protocols){
    if(protocols && protocols.length === 2 && protocols[1].startsWith(AUTH_TOKEN_PREFIX)){
      this.authToken = atob(protocols[1].slice(AUTH_TOKEN_PREFIX.length))
    }
    this.endpoint = this.normalizeEndpoint(endPoint)
    this.transport = null
    this.stream = null
    this.reader = null
    this.writer = null
    this.readBuffer = new Uint8Array(0)
    this.maxFrameSize = MAX_FRAME_SIZE
    this.bufferedAmount = 0
    this.timeout = null
    this.binaryType = "arraybuffer"
    this.readyState = SOCKET_STATES.connecting
    this.onopen = function (){ } // noop
    this.onerror = function (){ } // noop
    this.onmessage = function (){ } // noop
    this.onclose = function (){ } // noop
    this.writeChain = Promise.resolve()
    this.closeSent = false
    this.didClose = false
    setTimeout(() => this.connect(), 0)
  }

  normalizeEndpoint(endPoint){
    return (endPoint
      .replace("ws://", "https://")
      .replace("wss://", "https://")
      .replace(new RegExp("(.*)\/" + TRANSPORTS.websocket), "$1/" + TRANSPORTS.webtransport))
  }

  endpointURL(){
    let url = this.toURL(this.endpoint)
    if(this.authToken){
      url.searchParams.set("auth_token", this.authToken)
    }
    return url.toString()
  }

  toURL(url){
    try {
      return new URL(url)
    } catch (_error){
      let base = global.location ? `${global.location.protocol}//${global.location.host}` : "https://localhost"
      return new URL(url, base)
    }
  }

  async connect(){
    if(!global.WebTransport){
      this.onerror("webtransport unavailable")
      this.finalizeClose({code: 1006, reason: "webtransport unavailable", wasClean: false})
      return
    }

    try {
      this.transport = new global.WebTransport(this.endpointURL())
      this.transport.closed
        .then(({closeCode, reason}) => {
          this.finalizeClose({code: closeCode || 1000, reason, wasClean: true})
        })
        .catch(error => {
          if(!this.didClose){
            this.onerror(error)
            this.finalizeClose({code: 1011, reason: "transport error", wasClean: false})
          }
        })

      await this.transport.ready
      if(this.didClose){ return }

      this.stream = await this.transport.createBidirectionalStream()
      this.reader = this.stream.readable.getReader()
      this.writer = this.stream.writable.getWriter()
      this.readyState = SOCKET_STATES.open
      this.onopen({})
      this.readLoop()
    } catch (error){
      this.onerror(error)
      this.finalizeClose({code: 1011, reason: "transport setup failed", wasClean: false})
    }
  }

  send(body){
    if(this.readyState !== SOCKET_STATES.open || this.didClose){ return }

    if(typeof (body) !== "string"){
      this.onerror("binary frames unsupported")
      this.close(1003, "binary frames unsupported")
      return
    }

    let payload = encodeText(body)
    if(payload.byteLength > this.maxFrameSize){
      this.onerror("frame too large")
      this.close(1009, "frame too large")
      return
    }

    let frame = new Uint8Array(HEADER_SIZE + payload.byteLength)
    let view = new DataView(frame.buffer)
    view.setUint8(0, TEXT_FRAME_TYPE)
    view.setUint32(1, payload.byteLength)
    frame.set(payload, HEADER_SIZE)

    this.bufferedAmount += frame.byteLength
    this.writeChain = this.writeChain
      .then(() => this.writer.write(frame))
      .then(() => {
        this.bufferedAmount -= frame.byteLength
      })
      .catch(error => {
        this.bufferedAmount = 0
        this.onerror(error)
        this.close(1011, "write failed")
      })
  }

  close(code, reason){
    if(this.didClose){ return }
    this.readyState = SOCKET_STATES.closing

    if(this.transport && !this.closeSent){
      this.closeSent = true

      try {
        this.transport.close({closeCode: code || 1000, reason: reason || ""})
      } catch (error){
        this.onerror(error)
        this.finalizeClose({code: code || 1000, reason, wasClean: false})
      }
    } else if(!this.transport){
      this.finalizeClose({code: code || 1000, reason, wasClean: true})
    }
  }

  async readLoop(){
    try {
      while(this.reader && !this.didClose){
        let {done, value} = await this.reader.read()
        if(done){ break }
        this.readBuffer = appendBuffer(this.readBuffer, value)
        if(!this.processReadBuffer()){ return }
      }

      this.finalizeClose({code: 1000, reason: "", wasClean: true})
    } catch (error){
      if(!this.didClose){
        this.onerror(error)
        this.finalizeClose({code: 1011, reason: "read failed", wasClean: false})
      }
    }
  }

  processReadBuffer(){
    while(this.readBuffer.byteLength >= HEADER_SIZE){
      let view = new DataView(this.readBuffer.buffer, this.readBuffer.byteOffset, this.readBuffer.byteLength)
      let type = view.getUint8(0)
      let len = view.getUint32(1)

      if(len > this.maxFrameSize){
        this.onerror("frame too large")
        this.close(1009, "frame too large")
        return false
      }

      if(this.readBuffer.byteLength < HEADER_SIZE + len){ return true }

      let payload = this.readBuffer.slice(HEADER_SIZE, HEADER_SIZE + len)
      this.readBuffer = this.readBuffer.slice(HEADER_SIZE + len)

      if(type !== TEXT_FRAME_TYPE){
        this.onerror("binary frames unsupported")
        this.close(1003, "binary frames unsupported")
        return false
      }

      this.onmessage({data: decodeText(payload)})
    }

    return true
  }

  finalizeClose(opts){
    if(this.didClose){ return }
    this.didClose = true
    this.readyState = SOCKET_STATES.closed
    this.bufferedAmount = 0

    if(this.reader){
      this.reader.cancel().catch(() => {})
      this.reader.releaseLock()
      this.reader = null
    }

    if(this.writer){
      this.writer.releaseLock()
      this.writer = null
    }

    this.stream = null

    let closeOpts = Object.assign({code: 1000, reason: "", wasClean: true}, opts)
    if(typeof (CloseEvent) !== "undefined"){
      this.onclose(new CloseEvent("close", closeOpts))
    } else {
      this.onclose(closeOpts)
    }
  }
}
