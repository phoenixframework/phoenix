import {jest} from "@jest/globals"
import WebTransport from "../js/phoenix/webtransport"
import {Socket, LongPoll} from "../js/phoenix"
import {AUTH_TOKEN_PREFIX, SOCKET_STATES} from "../js/phoenix/constants"

let originalWebTransport

let mockWebTransport = () => {
  let writer = {
    write: jest.fn(() => Promise.resolve()),
    releaseLock: jest.fn()
  }

  let reader = {
    read: jest.fn(() => new Promise(() => {})),
    cancel: jest.fn(() => Promise.resolve()),
    releaseLock: jest.fn()
  }

  let stream = {
    readable: {getReader: () => reader},
    writable: {getWriter: () => writer}
  }

  let closeResolve
  let transport = {
    ready: Promise.resolve(),
    closed: new Promise(resolve => {
      closeResolve = resolve
    }),
    createBidirectionalStream: jest.fn(() => Promise.resolve(stream)),
    close: jest.fn()
  }

  global.WebTransport = jest.fn(() => transport)
  return {transport, writer, closeResolve}
}

describe("WebTransport", () => {
  beforeEach(() => {
    originalWebTransport = global.WebTransport
  })

  afterEach(() => {
    global.WebTransport = originalWebTransport
  })

  it("normalizes websocket endpoint and appends auth token query param", () => {
    mockWebTransport()
    let authToken = "my-auth-token"
    let encoded = btoa(authToken).replace(/=/g, "")
    let protocols = ["phoenix", `${AUTH_TOKEN_PREFIX}${encoded}`]

    let transport = new WebTransport("wss://example.com/socket/websocket?vsn=2.0.0", protocols)
    expect(transport.endpoint).toBe("https://example.com/socket/webtransport?vsn=2.0.0")
    expect(transport.endpointURL()).toContain("auth_token=my-auth-token")
  })

  it("encodes outgoing text messages as tlv frames", async () => {
    let {writer, closeResolve} = mockWebTransport()
    let transport = new WebTransport("wss://example.com/socket/websocket?vsn=2.0.0")

    await new Promise(resolve => {
      transport.onopen = () => resolve()
    })

    expect(transport.readyState).toBe(SOCKET_STATES.open)

    transport.send("ok")
    await transport.writeChain

    expect(writer.write).toHaveBeenCalledTimes(1)
    let frame = writer.write.mock.calls[0][0]
    let view = new DataView(frame.buffer, frame.byteOffset, frame.byteLength)

    expect(frame[0]).toBe(0)
    expect(view.getUint32(1)).toBe(2)
    expect(Array.from(frame.slice(5))).toEqual([111, 107])

    transport.close(1000, "")
    closeResolve({closeCode: 1000, reason: ""})
  })
})

describe("Socket WebTransport fallback", () => {
  let originalWebSocket

  beforeEach(() => {
    originalWebSocket = global.WebSocket
  })

  afterEach(() => {
    global.WebSocket = originalWebSocket
  })

  it("uses WebSocket as first fallback when transport is WebTransport", () => {
    function FakeWebSocket(){}
    global.WebSocket = FakeWebSocket

    let socket = new Socket("/socket", {
      transport: WebTransport,
      longPollFallbackMs: 20
    })

    let fallbackSpy = jest.spyOn(socket, "connectWithFallback").mockImplementation(() => {})

    socket.connect()

    expect(fallbackSpy).toHaveBeenCalledWith(FakeWebSocket, 20)
  })

  it("chains fallback to LongPoll after non-LongPoll fallback", () => {
    jest.useFakeTimers()

    function FakeWebSocket(){}

    let socket = new Socket("/socket", {
      transport: WebTransport,
      longPollFallbackMs: 20
    })

    socket.transportConnect = jest.fn()
    let fallbackSpy = jest.spyOn(socket, "connectWithFallback")

    socket.connectWithFallback(FakeWebSocket, 20)

    let errorCallback = socket.stateChangeCallbacks.error[socket.stateChangeCallbacks.error.length - 1][1]
    errorCallback("failed")

    expect(fallbackSpy).toHaveBeenNthCalledWith(2, LongPoll, 20)
    jest.useRealTimers()
  })
})
