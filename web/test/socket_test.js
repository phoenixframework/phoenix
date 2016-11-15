import assert from "assert"

import jsdom from "jsdom"
import { WebSocket, Server as WebSocketServer } from "mock-socket"
import { XMLHttpRequest } from "xmlhttprequest"

import { Socket, LongPoll } from "../static/js/phoenix"

let socket

describe("protocol", () => {
  before(() => {
    socket = new Socket("/socket")
  })

  it("returns wss when location.protocal is https", () => {
    jsdom.changeURL(window, "https://example.com/");

    assert.equal(socket.protocol(), "wss")
  })

  it("returns ws when location.protocal is http", () => {
    jsdom.changeURL(window, "http://example.com/");

    assert.equal(socket.protocol(), "ws")
  })
})

describe("endpointURL", () => {
  it("returns endpoint for given full url", () => {
    jsdom.changeURL(window, "https://example.com/");
    socket = new Socket("wss://example.org/chat")

    assert.equal(socket.endPointURL(), "wss://example.org/chat/websocket?vsn=1.0.0")
  })

  it("returns endpoint for given protocol-relative url", () => {
    jsdom.changeURL(window, "https://example.com/");
    socket = new Socket("//example.org/chat")

    assert.equal(socket.endPointURL(), "wss://example.org/chat/websocket?vsn=1.0.0")
  })

  it("returns endpoint for given path on https host", () => {
    jsdom.changeURL(window, "https://example.com/");
    socket = new Socket("/socket")

    assert.equal(socket.endPointURL(), "wss://example.com/socket/websocket?vsn=1.0.0")
  })

  it("returns endpoint for given path on http host", () => {
    jsdom.changeURL(window, "http://example.com/");
    socket = new Socket("/socket")

    assert.equal(socket.endPointURL(), "ws://example.com/socket/websocket?vsn=1.0.0")
  })
})

describe("connect with WebSocket", () => {
  let mockServer

  before(() => {
    mockServer = new WebSocketServer('wss://example.com/')
    jsdom.changeURL(window, "http://example.com/");
  })

  after(() => {
    mockServer.stop()
    window.WebSocket = null
  })

  it("establishes websocket connection with endpoint", () => {
    socket = new Socket("/socket")
    socket.connect()

    let conn = socket.conn
    assert.ok(conn instanceof WebSocket)
    assert.equal(conn.url, socket.endPointURL())
  })

  it("sets callbacks for connection", () => {
    socket = new Socket("/socket")
    let opens = 0
    socket.onOpen(() => ++opens)
    let closes = 0
    socket.onClose(() => ++closes)
    let lastError
    socket.onError((error) => lastError = error)
    let lastMessage
    socket.onMessage((message) => lastMessage = message.payload)

    socket.connect()

    socket.conn.onopen[0]()
    assert.equal(opens, 1)

    socket.conn.onclose[0]()
    assert.equal(closes, 1)

    socket.conn.onerror[0]("error")
    assert.equal(lastError, "error")

    socket.conn.onmessage[0]({data: '{"topic":"topic","event":"event","payload":"message","status":"ok"}'})
    assert.equal(lastMessage, "message")
  })

  it("is idempotent", () => {
    socket = new Socket("/socket")
    socket.connect()

    let conn = socket.conn

    socket.connect()

    assert.deepStrictEqual(conn, socket.conn)
  })
})

describe("connect with long poll", () => {
  before(() => {
    window.XMLHttpRequest = XMLHttpRequest
  })

  after(() => {
    window.XMLHttpRequest = null
  })

  it("establishes long poll connection with endpoint", () => {
    socket = new Socket("/socket")
    socket.connect()

    let conn = socket.conn
    assert.ok(conn instanceof LongPoll)
    assert.equal(conn.pollEndpoint, "http://example.com/socket/longpoll?vsn=1.0.0")
    assert.equal(conn.timeout, 20000)
  })

  it("sets callbacks for connection", () => {
    socket = new Socket("/socket")
    let opens = 0
    socket.onOpen(() => ++opens)
    let closes = 0
    socket.onClose(() => ++closes)
    let lastError
    socket.onError((error) => lastError = error)
    let lastMessage
    socket.onMessage((message) => lastMessage = message.payload)

    socket.connect()

    socket.conn.onopen()
    assert.equal(opens, 1)

    socket.conn.onclose()
    assert.equal(closes, 1)

    socket.conn.onerror("error")
    assert.equal(lastError, "error")

    socket.conn.onmessage({data: '{"topic":"topic","event":"event","payload":"message","status":"ok"}'})
    assert.equal(lastMessage, "message")
  })

  it("is idempotent", () => {
    socket = new Socket("/socket")
    socket.connect()

    let conn = socket.conn

    socket.connect()

    assert.deepStrictEqual(conn, socket.conn)
  })
})
