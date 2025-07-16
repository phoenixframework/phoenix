import {
  SOCKET_STATES,
  TRANSPORTS,
  AUTH_TOKEN_PREFIX,
  type SocketState
} from "./constants"

import Ajax from "./ajax"

function arrayBufferToBase64(buffer: ArrayBuffer): string {
  let binary = ""
  let bytes = new Uint8Array(buffer)
  let len = bytes.byteLength
  for (let i = 0; i < len; i++) { 
    binary += String.fromCharCode(bytes[i]!) 
  }
  return btoa(binary)
}

interface LongPollResponse {
  status: number
  token?: string
  messages?: string[]
}

interface MessageEvent {
  data: string
}

interface CloseEventInit {
  code?: number
  reason?: string
  wasClean?: boolean
}

export default class LongPoll {
  public endPoint: string | null
  public token: string | null
  public skipHeartbeat: boolean
  public reqs: Set<any>
  public awaitingBatchAck: boolean
  public currentBatch: string[] | null
  public currentBatchTimer: number | null
  public batchBuffer: string[]
  public onopen: (event: any) => void
  public onerror: (error: any) => void
  public onmessage: (event: MessageEvent) => void
  public onclose: (event: CloseEvent | CloseEventInit) => void
  public pollEndpoint: string
  public readyState: SocketState
  public timeout: number
  public authToken?: string

  constructor(endPoint: string, protocols?: string[]) {
    // we only support subprotocols for authToken
    // ["phoenix", "base64url.bearer.phx.BASE64_ENCODED_TOKEN"]
    if (protocols && protocols.length === 2 && protocols[1]!.startsWith(AUTH_TOKEN_PREFIX)) {
      this.authToken = atob(protocols[1]!.slice(AUTH_TOKEN_PREFIX.length))
    }
    this.endPoint = null
    this.token = null
    this.skipHeartbeat = true
    this.reqs = new Set()
    this.awaitingBatchAck = false
    this.currentBatch = null
    this.currentBatchTimer = null
    this.batchBuffer = []
    this.onopen = function () { } // noop
    this.onerror = function () { } // noop
    this.onmessage = function () { } // noop
    this.onclose = function () { } // noop
    this.pollEndpoint = this.normalizeEndpoint(endPoint)
    this.readyState = SOCKET_STATES.connecting
    this.timeout = 20000 // will be set by Socket
    // we must wait for the caller to finish setting up our callbacks and timeout properties
    setTimeout(() => this.poll(), 0)
  }

  normalizeEndpoint(endPoint: string): string {
    return (endPoint
      .replace("ws://", "http://")
      .replace("wss://", "https://")
      .replace(new RegExp("(.*)\/" + TRANSPORTS.websocket), "$1/" + TRANSPORTS.longpoll))
  }

  endpointURL(): string {
    return Ajax.appendParams(this.pollEndpoint, { token: this.token })
  }

  closeAndRetry(code: number, reason: string, wasClean: boolean): void {
    this.close(code, reason, wasClean)
    this.readyState = SOCKET_STATES.connecting
  }

  ontimeout(): void {
    this.onerror("timeout")
    this.closeAndRetry(1005, "timeout", false)
  }

  isActive(): boolean { 
    return this.readyState === SOCKET_STATES.open || this.readyState === SOCKET_STATES.connecting 
  }

  poll(): void {
    const headers: Record<string, string> = { "Accept": "application/json" }
    if (this.authToken) {
      headers["X-Phoenix-AuthToken"] = this.authToken
    }
    this.ajax("GET", headers, null, () => this.ontimeout(), (resp: LongPollResponse | null) => {
      let status: number
      if (resp) {
        var { status: respStatus, token, messages } = resp
        status = respStatus
        this.token = token || null
      } else {
        status = 0
      }

      switch (status) {
        case 200:
          resp!.messages!.forEach(msg => {
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
            setTimeout(() => this.onmessage({ data: msg }), 0)
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
          this.closeAndRetry(1011, "internal server error", false)
          break
        default: throw new Error(`unhandled poll status ${status}`)
      }
    })
  }

  // we collect all pushes within the current event loop by
  // setTimeout 0, which optimizes back-to-back procedural
  // pushes against an empty buffer

  send(body: string | ArrayBuffer): void {
    let bodyStr: string
    if (typeof (body) !== "string") { 
      bodyStr = arrayBufferToBase64(body) 
    } else {
      bodyStr = body
    }
    if (this.currentBatch) {
      this.currentBatch.push(bodyStr)
    } else if (this.awaitingBatchAck) {
      this.batchBuffer.push(bodyStr)
    } else {
      this.currentBatch = [bodyStr]
      this.currentBatchTimer = setTimeout(() => {
        this.batchSend(this.currentBatch!)
        this.currentBatch = null
      }, 0) as any
    }
  }

  batchSend(messages: string[]): void {
    this.awaitingBatchAck = true
    this.ajax("POST", { "Content-Type": "application/x-ndjson" }, messages.join("\n"), () => this.onerror("timeout"), (resp: any) => {
      this.awaitingBatchAck = false
      if (!resp || resp.status !== 200) {
        this.onerror(resp && resp.status)
        this.closeAndRetry(1011, "internal server error", false)
      } else if (this.batchBuffer.length > 0) {
        this.batchSend(this.batchBuffer)
        this.batchBuffer = []
      }
    })
  }

  close(code?: number, reason?: string, wasClean?: boolean): void {
    for (let req of this.reqs) { req.abort() }
    this.readyState = SOCKET_STATES.closed
    let opts = Object.assign({ code: 1000, reason: undefined, wasClean: true }, { code, reason, wasClean })
    this.batchBuffer = []
    if (this.currentBatchTimer !== null) {
      clearTimeout(this.currentBatchTimer)
      this.currentBatchTimer = null
    }
    if (typeof (CloseEvent) !== "undefined") {
      this.onclose(new CloseEvent("close", opts))
    } else {
      this.onclose(opts)
    }
  }

  ajax(
    method: "GET" | "POST",
    headers: Record<string, string>,
    body: string | null,
    onCallerTimeout: () => void,
    callback: (resp: any) => void
  ): void {
    let req: any
    let ontimeout = () => {
      this.reqs.delete(req)
      onCallerTimeout()
    }
    req = Ajax.request(method, this.endpointURL(), headers, body, this.timeout, ontimeout, (resp: any) => {
      this.reqs.delete(req)
      if (this.isActive()) { callback(resp) }
    })
    this.reqs.add(req)
  }
}