import assert from "assert"

import jsdom from "jsdom"
import sinon from "sinon"
import {WebSocket, Server as WebSocketServer} from "mock-socket"
import {encode} from "./serializer"
import {Socket, LongPoll} from "../js/phoenix"

let socket

describe("with transports", function(){
  before(function(){
    window.WebSocket = WebSocket
    window.XMLHttpRequest = sinon.useFakeXMLHttpRequest()
  })

  after(function(done){
    window.WebSocket = null
    window.XMLHttpRequest = null
    done()
  })

  describe("constructor", function(){
    it("sets defaults", function(){
      socket = new Socket("/socket")

      assert.equal(socket.channels.length, 0)
      assert.equal(socket.sendBuffer.length, 0)
      assert.equal(socket.ref, 0)
      assert.equal(socket.endPoint, "/socket/websocket")
      assert.deepEqual(socket.stateChangeCallbacks, {open: [], close: [], error: [], message: []})
      assert.equal(socket.transport, WebSocket)
      assert.equal(socket.timeout, 10000)
      assert.equal(socket.longpollerTimeout, 20000)
      assert.equal(socket.heartbeatIntervalMs, 30000)
      assert.equal(socket.logger, null)
      assert.equal(socket.binaryType, "arraybuffer")
      assert.equal(typeof socket.reconnectAfterMs, "function")
    })

    it("supports closure or literal params", function(){
      socket = new Socket("/socket", {params: {one: "two"}})
      assert.deepEqual(socket.params(), {one: "two"})

      socket = new Socket("/socket", {params: function(){ return ({three: "four"}) }})
      assert.deepEqual(socket.params(), {three: "four"})
    })

    it("overrides some defaults with options", function(){
      const customTransport = function transport(){}
      const customLogger = function logger(){}
      const customReconnect = function reconnect(){}

      socket = new Socket("/socket", {
        timeout: 40000,
        longpollerTimeout: 50000,
        heartbeatIntervalMs: 60000,
        transport: customTransport,
        logger: customLogger,
        reconnectAfterMs: customReconnect,
        params: {one: "two"},
      })

      assert.equal(socket.timeout, 40000)
      assert.equal(socket.longpollerTimeout, 50000)
      assert.equal(socket.heartbeatIntervalMs, 60000)
      assert.equal(socket.transport, customTransport)
      assert.equal(socket.logger, customLogger)
      assert.deepEqual(socket.params(), {one: "two"})
    })

    describe("with Websocket", function(){
      it("defaults to Websocket transport if available", function(done){
        let mockServer
        mockServer = new WebSocketServer("wss://example.com/")
        socket = new Socket("/socket")
        assert.equal(socket.transport, WebSocket)
        mockServer.stop(() => done())
      })
    })
  })

  describe("protocol", function(){
    beforeEach(function(){
      socket = new Socket("/socket")
    })

    it("returns wss when location.protocol is https", function(){
      jsdom.changeURL(window, "https://example.com/")

      assert.equal(socket.protocol(), "wss")
    })

    it("returns ws when location.protocol is http", function(){
      jsdom.changeURL(window, "http://example.com/")

      assert.equal(socket.protocol(), "ws")
    })
  })

  describe("endpointURL", function(){
    it("returns endpoint for given full url", function(){
      jsdom.changeURL(window, "https://example.com/")
      socket = new Socket("wss://example.org/chat")

      assert.equal(socket.endPointURL(), "wss://example.org/chat/websocket?vsn=2.0.0")
    })

    it("returns endpoint for given protocol-relative url", function(){
      jsdom.changeURL(window, "https://example.com/")
      socket = new Socket("//example.org/chat")

      assert.equal(socket.endPointURL(), "wss://example.org/chat/websocket?vsn=2.0.0")
    })

    it("returns endpoint for given path on https host", function(){
      jsdom.changeURL(window, "https://example.com/")
      socket = new Socket("/socket")

      assert.equal(socket.endPointURL(), "wss://example.com/socket/websocket?vsn=2.0.0")
    })

    it("returns endpoint for given path on http host", function(){
      jsdom.changeURL(window, "http://example.com/")
      socket = new Socket("/socket")

      assert.equal(socket.endPointURL(), "ws://example.com/socket/websocket?vsn=2.0.0")
    })
  })

  describe("connect with WebSocket", function(){
    let mockServer

    before(function(){
      mockServer = new WebSocketServer("wss://example.com/")
    })

    after(function(done){
      mockServer.stop(() => done())
    })

    beforeEach(function(){
      socket = new Socket("/socket")
    })

    it("establishes websocket connection with endpoint", function(){
      socket.connect()

      let conn = socket.conn
      assert.ok(conn instanceof WebSocket)
      assert.equal(conn.url, socket.endPointURL())
    })

    it("sets callbacks for connection", function(){
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

      const data = {"topic":"topic", "event":"event", "payload":"payload", "status":"ok"}
      socket.conn.onmessage[0]({data: encode(data)})
      assert.equal(lastMessage, "payload")
    })

    it("is idempotent", function(){
      socket.connect()

      let conn = socket.conn

      socket.connect()

      assert.deepStrictEqual(conn, socket.conn)
    })
  })

  describe("connect with long poll", function(){
    beforeEach(function(){
      socket = new Socket("/socket", {transport: LongPoll})
    })

    it("establishes long poll connection with endpoint", function(){
      socket.connect()

      let conn = socket.conn
      assert.ok(conn instanceof LongPoll)
      assert.equal(conn.pollEndpoint, "http://example.com/socket/longpoll?vsn=2.0.0")
      assert.equal(conn.timeout, 20000)
    })

    it("sets callbacks for connection", function(){
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

      socket.connect()

      const data = {"topic":"topic", "event":"event", "payload":"payload", "status":"ok"}

      socket.conn.onmessage({data: encode(data)})
      assert.equal(lastMessage, "payload")
    })

    it("is idempotent", function(){
      socket.connect()

      let conn = socket.conn

      socket.connect()

      assert.deepStrictEqual(conn, socket.conn)
    })
  })

  describe("disconnect", function(){
    let mockServer

    before(function(){
      mockServer = new WebSocketServer("wss://example.com/")
    })

    after(function(done){
      mockServer.stop(() => done())
    })

    beforeEach(function(){
      socket = new Socket("/socket")
    })

    it("removes existing connection", function(done){
      socket.connect()
      socket.disconnect()
      socket.disconnect(() => {
        assert.equal(socket.conn, null)
        done()
      })
    })

    it("calls callback", function(done){
      let count = 0
      socket.connect()
      socket.disconnect(() => {
        count++
        assert.equal(count, 1)
        done()
      })
    })

    it("calls connection close callback", function(done){
      socket.connect()
      const spy = sinon.spy(socket.conn, "close")

      socket.disconnect(() => {
        assert(spy.calledWith(1000, "reason"))
        done()
      }, 1000, "reason")
    })

    it("does not throw when no connection", function(){
      assert.doesNotThrow(() => {
        socket.disconnect()
      })
    })
  })

  describe("connectionState", function(){
    beforeEach(function(){
      socket = new Socket("/socket")
    })

    it("defaults to closed", function(){
      assert.equal(socket.connectionState(), "closed")
    })

    it("returns closed if readyState unrecognized", function(){
      socket.connect()

      socket.conn.readyState = 5678
      assert.equal(socket.connectionState(), "closed")
    })

    it("returns connecting", function(){
      socket.connect()

      socket.conn.readyState = 0
      assert.equal(socket.connectionState(), "connecting")
      assert.ok(!socket.isConnected(), "is not connected")
    })

    it("returns open", function(){
      socket.connect()

      socket.conn.readyState = 1
      assert.equal(socket.connectionState(), "open")
      assert.ok(socket.isConnected(), "is connected")
    })

    it("returns closing", function(){
      socket.connect()

      socket.conn.readyState = 2
      assert.equal(socket.connectionState(), "closing")
      assert.ok(!socket.isConnected(), "is not connected")
    })

    it("returns closed", function(){
      socket.connect()

      socket.conn.readyState = 3
      assert.equal(socket.connectionState(), "closed")
      assert.ok(!socket.isConnected(), "is not connected")
    })
  })

  describe("channel", function(){
    let channel

    beforeEach(function(){
      socket = new Socket("/socket")
    })

    it("returns channel with given topic and params", function(){
      channel = socket.channel("topic", {one: "two"})

      assert.deepStrictEqual(channel.socket, socket)
      assert.equal(channel.topic, "topic")
      assert.deepEqual(channel.params(), {one: "two"})
    })

    it("adds channel to sockets channels list", function(){
      assert.equal(socket.channels.length, 0)

      channel = socket.channel("topic", {one: "two"})

      assert.equal(socket.channels.length, 1)

      const [foundChannel] = socket.channels
      assert.deepStrictEqual(foundChannel, channel)
    })
  })

  describe("remove", function(){
    it("removes given channel from channels", function(){
      socket = new Socket("/socket")
      const channel1 = socket.channel("topic-1")
      const channel2 = socket.channel("topic-2")

      sinon.stub(channel1, "joinRef").returns(1)
      sinon.stub(channel2, "joinRef").returns(2)

      assert.equal(socket.stateChangeCallbacks.open.length, 2)

      socket.remove(channel1)

      assert.equal(socket.stateChangeCallbacks.open.length, 1)

      assert.equal(socket.channels.length, 1)

      const [foundChannel] = socket.channels
      assert.deepStrictEqual(foundChannel, channel2)
    })
  })

  describe("push", function(){
    let data, json

    beforeEach(function(){
      data = {topic: "topic", event: "event", payload: "payload", ref: "ref"}
      json = encode(data)
      socket = new Socket("/socket")
    })

    it("sends data to connection when connected", function(){
      socket.connect()
      socket.conn.readyState = 1 // open

      const spy = sinon.spy(socket.conn, "send")

      socket.push(data)

      assert.ok(spy.calledWith(json))
    })

    it("buffers data when not connected", function(){
      socket.connect()
      socket.conn.readyState = 0 // connecting

      const spy = sinon.spy(socket.conn, "send")

      assert.equal(socket.sendBuffer.length, 0)

      socket.push(data)

      assert.ok(spy.neverCalledWith(json))
      assert.equal(socket.sendBuffer.length, 1)

      const [callback] = socket.sendBuffer
      callback()
      assert.ok(spy.calledWith(json))
    })
  })

  describe("makeRef", function(){
    beforeEach(function(){
      socket = new Socket("/socket")
    })

    it("returns next message ref", function(){
      assert.strictEqual(socket.ref, 0)
      assert.strictEqual(socket.makeRef(), "1")
      assert.strictEqual(socket.ref, 1)
      assert.strictEqual(socket.makeRef(), "2")
      assert.strictEqual(socket.ref, 2)
    })

    it("restarts for overflow", function(){
      socket.ref = Number.MAX_SAFE_INTEGER + 1

      assert.strictEqual(socket.makeRef(), "0")
      assert.strictEqual(socket.ref, 0)
    })
  })

  describe("sendHeartbeat", function(){
    beforeEach(function(){
      socket = new Socket("/socket")
      socket.connect()
    })

    it("closes socket when heartbeat is not ack'd within heartbeat window", function(done){
      let clock = sinon.useFakeTimers()
      let closed = false
      socket.conn.readyState = 1 // open
      socket.conn.close = () => closed = true
      socket.sendHeartbeat()
      assert.strictEqual(closed, false)

      clock.tick(10000)
      assert.strictEqual(closed, false)

      clock.tick(20010)
      assert.strictEqual(closed, true)

      clock.restore()
      done()
    })

    it("pushes heartbeat data when connected", function(){
      socket.conn.readyState = 1 // open

      const spy = sinon.spy(socket.conn, "send")
      const data = "[null,\"1\",\"phoenix\",\"heartbeat\",{}]"

      socket.sendHeartbeat()
      assert.ok(spy.calledWith(data))
    })

    it("no ops when not connected", function(){
      socket.conn.readyState = 0 // connecting

      const spy = sinon.spy(socket.conn, "send")
      const data = encode({topic: "phoenix", event: "heartbeat", payload: {}, ref: "1"})

      socket.sendHeartbeat()
      assert.ok(spy.neverCalledWith(data))
    })
  })

  describe("flushSendBuffer", function(){
    beforeEach(function(){
      socket = new Socket("/socket")
      socket.connect()
    })

    it("calls callbacks in buffer when connected", function(){
      socket.conn.readyState = 1 // open
      const spy1 = sinon.spy()
      const spy2 = sinon.spy()
      const spy3 = sinon.spy()
      socket.sendBuffer.push(spy1)
      socket.sendBuffer.push(spy2)

      socket.flushSendBuffer()

      assert.ok(spy1.calledOnce)
      assert.ok(spy2.calledOnce)
      assert.equal(spy3.callCount, 0)
    })

    it("empties sendBuffer", function(){
      socket.conn.readyState = 1 // open
      socket.sendBuffer.push(() => {})

      socket.flushSendBuffer()

      assert.deepEqual(socket.sendBuffer.length, 0)
    })
  })

  describe("onConnOpen", function(){
    let mockServer

    before(function(){
      mockServer = new WebSocketServer("wss://example.com/")
    })

    after(function(done){
      mockServer.stop(() => done())
    })

    beforeEach(function(){
      socket = new Socket("/socket", {
        reconnectAfterMs: () => 100000
      })
      socket.connect()
    })

    it("flushes the send buffer", function(){
      socket.conn.readyState = 1 // open
      const spy = sinon.spy()
      socket.sendBuffer.push(spy)

      socket.onConnOpen()

      assert.ok(spy.calledOnce)
    })

    it("resets reconnectTimer", function(){
      const spy = sinon.spy(socket.reconnectTimer, "reset")

      socket.onConnOpen()

      assert.ok(spy.calledOnce)
    })

    it("triggers onOpen callback", function(){
      const spy = sinon.spy()

      socket.onOpen(spy)

      socket.onConnOpen()

      assert.ok(spy.calledOnce)
    })
  })

  describe("onConnClose", function(){
    let mockServer

    before(function(){
      mockServer = new WebSocketServer("wss://example.com/")
    })

    after(function(done){
      mockServer.stop(() => done())
    })

    beforeEach(function(){
      socket = new Socket("/socket", {
        reconnectAfterMs: () => 100000
      })
      socket.connect()
    })

    it("schedules reconnectTimer timeout if normal close", function(){
      const spy = sinon.spy(socket.reconnectTimer, "scheduleTimeout")

      const event = {code: 1000}

      socket.onConnClose(event)

      assert.ok(spy.calledOnce)
    })

    it("does not schedule reconnectTimer timeout if normal close after explicit disconnect", function(){
      const spy = sinon.spy(socket.reconnectTimer, "scheduleTimeout")

      socket.disconnect()

      assert.ok(spy.notCalled)
    })

    it("schedules reconnectTimer timeout if not normal close", function(){
      const spy = sinon.spy(socket.reconnectTimer, "scheduleTimeout")

      const event = {code: 1001}

      socket.onConnClose(event)

      assert.ok(spy.calledOnce)
    })

    it("schedules reconnectTimer timeout if connection cannot be made after a previous clean disconnect", function(done){
      const spy = sinon.spy(socket.reconnectTimer, "scheduleTimeout")

      socket.disconnect(() => {
        socket.connect()

        const event = {code: 1001}

        socket.onConnClose(event)

        assert.ok(spy.calledOnce)
        done()
      })
    })

    it("triggers onClose callback", function(){
      const spy = sinon.spy()

      socket.onClose(spy)

      socket.onConnClose("event")

      assert.ok(spy.calledWith("event"))
    })

    it("triggers channel error if joining", function(){
      const channel = socket.channel("topic")
      const spy = sinon.spy(channel, "trigger")
      channel.join()
      assert.equal(channel.state, "joining")

      socket.onConnClose()

      assert.ok(spy.calledWith("phx_error"))
    })

    it("triggers channel error if joined", function(){
      const channel = socket.channel("topic")
      const spy = sinon.spy(channel, "trigger")
      channel.join().trigger("ok", {})

      assert.equal(channel.state, "joined")

      socket.onConnClose()

      assert.ok(spy.calledWith("phx_error"))
    })

    it("does not trigger channel error after leave", function(){
      const channel = socket.channel("topic")
      const spy = sinon.spy(channel, "trigger")
      channel.join().trigger("ok", {})
      channel.leave()
      assert.equal(channel.state, "closed")

      socket.onConnClose()

      assert.ok(!spy.calledWith("phx_error"))
    })
  })

  describe("onConnError", function(){
    let mockServer

    before(function(){
      mockServer = new WebSocketServer("wss://example.com/")
    })

    after(function(done){
      mockServer.stop(() => done())
    })

    beforeEach(function(){
      socket = new Socket("/socket", {
        reconnectAfterMs: () => 100000
      })
      socket.connect()
    })

    it("triggers onClose callback", function(){
      const spy = sinon.spy()

      socket.onError(spy)

      socket.onConnError("error")

      assert.ok(spy.calledWith("error"))
    })

    it("triggers channel error if joining with open connection", function(){
      const channel = socket.channel("topic")
      const spy = sinon.spy(channel, "trigger")
      channel.join()
      socket.onConnOpen()

      assert.equal(channel.state, "joining")

      socket.onConnError("error")

      assert.ok(spy.calledWith("phx_error"))
    })

    it("triggers channel error if joining with no connection", function(){
      const channel = socket.channel("topic")
      const spy = sinon.spy(channel, "trigger")
      channel.join()

      assert.equal(channel.state, "joining")

      socket.onConnError("error")

      assert.ok(spy.calledWith("phx_error"))
    })

    it("triggers channel error if joined", function(){
      const channel = socket.channel("topic")
      const spy = sinon.spy(channel, "trigger")
      channel.join().trigger("ok", {})
      socket.onConnOpen()

      assert.equal(channel.state, "joined")

      let connectionsCount = null
      let transport = null
      socket.onError((error, erroredTransport, conns) => {
        transport = erroredTransport
        connectionsCount = conns
      })

      socket.onConnError("error")

      assert.equal(transport, WebSocket)
      assert.equal(connectionsCount, 1)
      assert.ok(spy.calledWith("phx_error"))
    })

    it("does not trigger channel error after leave", function(){
      const channel = socket.channel("topic")
      const spy = sinon.spy(channel, "trigger")
      channel.join().trigger("ok", {})
      channel.leave()
      assert.equal(channel.state, "closed")

      socket.onConnError("error")

      assert.ok(!spy.calledWith("phx_error"))
    })

    it("does not trigger channel error if transport replaced with no previous connection", function(){
      const channel = socket.channel("topic")
      const spy = sinon.spy(channel, "trigger")
      channel.join()

      assert.equal(channel.state, "joining")

      let connectionsCount = null
      class FakeTransport{
      }

      socket.onError((error, transport, conns) => {
        socket.replaceTransport(FakeTransport)
        connectionsCount = conns
      })
      socket.onConnError("error")

      assert.equal(connectionsCount, 0)
      assert.equal(socket.transport, FakeTransport)
      assert.equal(spy.calledWith("phx_error"), false)
    })
  })

  describe("onConnMessage", function(){
    let mockServer

    before(function(){
      mockServer = new WebSocketServer("wss://example.com/")
    })

    after(function(done){
      mockServer.stop(() => done())
    })

    beforeEach(function(){
      socket = new Socket("/socket", {
        reconnectAfterMs: () => 100000
      })
      socket.connect()
    })

    it("parses raw message and triggers channel event", function(){
      const message = encode({topic: "topic", event: "event", payload: "payload", ref: "ref"})
      const data = {data: message}

      const targetChannel = socket.channel("topic")
      const otherChannel = socket.channel("off-topic")

      const targetSpy = sinon.spy(targetChannel, "trigger")
      const otherSpy = sinon.spy(otherChannel, "trigger")

      socket.onConnMessage(data)

      assert.ok(targetSpy.calledWith("event", "payload", "ref"))
      assert.equal(targetSpy.callCount, 1)
      assert.equal(otherSpy.callCount, 0)
    })

    it("triggers onMessage callback", function(){
      const message = {"topic":"topic", "event":"event", "payload":"payload", "ref":"ref"}
      const spy = sinon.spy()
      socket.onMessage(spy)
      socket.onConnMessage({data: encode(message)})

      assert.ok(spy.calledWith({
        "topic": "topic",
        "event": "event",
        "payload": "payload",
        "ref": "ref",
        "join_ref": null
      }))
    })
  })

  describe("custom encoder and decoder", function(){

    it("encodes to JSON array by default", function(){
      socket = new Socket("/socket")
      let payload = {topic: "topic", ref: "2", join_ref: "1", event: "join", payload: {foo: "bar"}}

      socket.encode(payload, encoded => {
        assert.deepStrictEqual(encoded, "[\"1\",\"2\",\"topic\",\"join\",{\"foo\":\"bar\"}]")
      })
    })

    it("allows custom encoding when using WebSocket transport", function(){
      let encoder = (payload, callback) => callback("encode works")
      socket = new Socket("/socket", {transport: WebSocket, encode: encoder})

      socket.encode({foo: "bar"}, encoded => {
        assert.deepStrictEqual(encoded, "encode works")
      })
    })

    it("forces JSON encoding when using LongPoll transport", function(){
      let encoder = (payload, callback) => callback("encode works")
      socket = new Socket("/socket", {transport: LongPoll, encode: encoder})
      let payload = {topic: "topic", ref: "2", join_ref: "1", event: "join", payload: {foo: "bar"}}

      socket.encode(payload, encoded => {
        assert.deepStrictEqual(encoded, "[\"1\",\"2\",\"topic\",\"join\",{\"foo\":\"bar\"}]")
      })
    })

    it("decodes JSON by default", function(){
      socket = new Socket("/socket")
      let encoded = "[\"1\",\"2\",\"topic\",\"join\",{\"foo\":\"bar\"}]"

      socket.decode(encoded, decoded => {
        assert.deepStrictEqual(decoded, {topic: "topic", ref: "2", join_ref: "1", event: "join", payload: {foo: "bar"}})
      })
    })

    it("allows custom decoding when using WebSocket transport", function(){
      let decoder = (payload, callback) => callback("decode works")
      socket = new Socket("/socket", {transport: WebSocket, decode: decoder})

      socket.decode("...esoteric format...", decoded => {
        assert.deepStrictEqual(decoded, "decode works")
      })
    })

    it("forces JSON decoding when using LongPoll transport", function(){
      let decoder = (payload, callback) => callback("decode works")
      socket = new Socket("/socket", {transport: LongPoll, decode: decoder})
      let payload = {topic: "topic", ref: "2", join_ref: "1", event: "join", payload: {foo: "bar"}}

      socket.decode("[\"1\",\"2\",\"topic\",\"join\",{\"foo\":\"bar\"}]", decoded => {
        assert.deepStrictEqual(decoded, payload)
      })
    })
  })

})
window.XMLHttpRequest = sinon.useFakeXMLHttpRequest()
window.WebSocket = WebSocket
