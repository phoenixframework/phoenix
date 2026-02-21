import {jest} from "@jest/globals"
import {WebSocket, Server as WebSocketServer} from "mock-socket"
import {encode} from "./serializer"
import {Socket, LongPoll} from "../js/phoenix"
import {SOCKET_STATES} from "../js/phoenix/constants"

let socket

describe("with transports", function (){
  beforeAll(() => {
    window.WebSocket = WebSocket
    const mockOpen = jest.fn()
    const mockSend = jest.fn()
    const mockAbort = jest.fn()
    const mockSetRequestHeader = jest.fn()
    
    global.XMLHttpRequest = jest.fn(() => ({
      open: mockOpen,
      send: mockSend,
      abort: mockAbort,
      setRequestHeader: mockSetRequestHeader,
      readyState: 4,
      status: 200,
      responseText: JSON.stringify({}),
      onreadystatechange: null,
    }))
  })

  describe("constructor", function (){
    it("sets defaults", function (){
      socket = new Socket("/socket")

      expect(socket.channels.length).toBe(0)
      expect(socket.sendBuffer.length).toBe(0)
      expect(socket.ref).toBe(0)
      expect(socket.endPoint).toBe("/socket/websocket")
      expect(socket.stateChangeCallbacks).toEqual({open: [], close: [], error: [], message: []})
      expect(socket.transport).toBe(WebSocket)
      expect(socket.timeout).toBe(10000)
      expect(socket.longpollerTimeout).toBe(20000)
      expect(socket.heartbeatIntervalMs).toBe(30000)
      expect(socket.logger).toBeNull()
      expect(socket.binaryType).toBe("arraybuffer")
      expect(typeof socket.reconnectAfterMs).toBe("function")
    })

    it("supports closure or literal params", function (){
      socket = new Socket("/socket", {params: {one: "two"}})
      expect(socket.params()).toEqual({one: "two"})

      socket = new Socket("/socket", {params: function (){ return ({three: "four"}) }})
      expect(socket.params()).toEqual({three: "four"})
    })

    it("overrides some defaults with options", function (){
      const customTransport = function transport(){ }
      const customLogger = function logger(){ }
      const customReconnect = function reconnect(){ }

      socket = new Socket("/socket", {
        timeout: 40000,
        longpollerTimeout: 50000,
        heartbeatIntervalMs: 60000,
        transport: customTransport,
        logger: customLogger,
        reconnectAfterMs: customReconnect,
        params: {one: "two"},
      })

      expect(socket.timeout).toBe(40000)
      expect(socket.longpollerTimeout).toBe(50000)
      expect(socket.heartbeatIntervalMs).toBe(60000)
      expect(socket.transport).toBe(customTransport)
      expect(socket.logger).toBe(customLogger)
      expect(socket.params()).toEqual({one: "two"})
    })

    describe("with Websocket", function (){
      it("defaults to Websocket transport if available", function (done){
        let mockServer = new WebSocketServer("wss://example.com/")
        socket = new Socket("/socket")
        expect(socket.transport).toBe(WebSocket)
        mockServer.stop(() => done())
      })
    })

    describe("longPollFallbackMs", function (){
      it("falls back to longpoll when set after primary transport failure", function (done){
        let mockServer
        socket = new Socket("/socket", {longPollFallbackMs: 20})
        const replaceSpy = jest.spyOn(socket, "replaceTransport")
        mockServer = new WebSocketServer("wss://example.test/")
        mockServer.stop(() => {
          expect(socket.transport).toBe(WebSocket)
          socket.onError((_reason) => {
            setTimeout(() => {
              expect(replaceSpy).toHaveBeenCalledWith(LongPoll)
              done()
            }, 100)
          })
          socket.connect()
        })
      })
    })
  })

  describe("protocol", function (){
    beforeEach(function (){
      socket = new Socket("/socket")
    })

    it("returns wss when location.protocol is https", function (){
      expect(socket.protocol()).toBe("wss")
    })
  })

  describe("endpointURL", function (){
    it("returns endpoint for given full url", function (){
      socket = new Socket("wss://example.org/chat")
      expect(socket.endPointURL()).toBe("wss://example.org/chat/websocket?vsn=2.0.0")
    })

    it("returns endpoint for given protocol-relative url", function (){
      socket = new Socket("//example.org/chat")
      expect(socket.endPointURL()).toBe("wss://example.org/chat/websocket?vsn=2.0.0")
    })

    it("returns endpoint for given path on https host", function (){
      socket = new Socket("/socket")
      expect(socket.endPointURL()).toBe("wss://example.com/socket/websocket?vsn=2.0.0")
    })
  })

  describe("connect with WebSocket", function (){
    let mockServer

    beforeAll(function (){
      mockServer = new WebSocketServer("wss://example.com/")
    })

    afterAll(function (done){
      mockServer.stop(() => done())
    })

    beforeEach(function (){
      socket = new Socket("/socket")
    })

    it("establishes websocket connection with endpoint", function (){
      socket.connect()
      const conn = socket.conn
      expect(conn instanceof WebSocket).toBeTruthy()
      expect(conn.url).toBe(socket.endPointURL())
    })

    it("sets callbacks for connection", function (){
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
      expect(opens).toBe(1)

      socket.conn.onclose()
      expect(closes).toBe(1)

      socket.conn.onerror("error")
      expect(lastError).toBe("error")

      const data = {"topic": "topic", "event": "event", "payload": "payload", "status": "ok"}
      socket.conn.onmessage({data: encode(data)})
      expect(lastMessage).toBe("payload")
    })

    it("is idempotent", function (){
      socket.connect()
      const conn = socket.conn
      socket.connect()
      expect(conn).toBe(socket.conn)
    })
  })

  describe("connect with long poll", function (){
    beforeEach(function (){
      socket = new Socket("/socket", {transport: LongPoll})
    })

    it("establishes long poll connection with endpoint", function (){
      socket.connect()
      const conn = socket.conn
      expect(conn instanceof LongPoll).toBeTruthy()
      expect(conn.pollEndpoint).toBe("https://example.com/socket/longpoll?vsn=2.0.0")
      expect(conn.timeout).toBe(20000)
    })

    it("sets callbacks for connection", function (){
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
      expect(opens).toBe(1)

      socket.conn.onclose()
      expect(closes).toBe(1)

      socket.conn.onerror("error")
      expect(lastError).toBe("error")

      socket.connect()

      const data = {"topic": "topic", "event": "event", "payload": "payload", "status": "ok"}

      socket.conn.onmessage({data: encode(data)})
      expect(lastMessage).toBe("payload")
    })

    it("is idempotent", function (){
      socket.connect()
      const conn = socket.conn
      socket.connect()
      expect(conn).toBe(socket.conn)
    })
  })

  describe("disconnect", function (){
    let mockServer

    beforeAll(function (){
      mockServer = new WebSocketServer("wss://example.com/")
    })

    afterAll(function (done){
      mockServer.stop(() => done())
    })

    beforeEach(function (){
      socket = new Socket("/socket")
    })

    it("removes existing connection", function (done){
      socket.connect()
      socket.disconnect()
      socket.disconnect(() => {
        expect(socket.conn).toBeNull()
        done()
      })
    })

    it("calls callback", function (done){
      let count = 0
      socket.connect()
      socket.disconnect(() => {
        count++
        expect(count).toBe(1)
        done()
      })
    })

    it("calls connection close callback", function (done){
      socket.connect()
      const closeSpy = jest.spyOn(socket.conn, "close")

      socket.disconnect(() => {
        expect(closeSpy).toHaveBeenCalledWith(1000, "reason")
        done()
      }, 1000, "reason")
    })

    it("does not throw when no connection", function (){
      expect(() => {
        socket.disconnect()
      }).not.toThrow()
    })

    it("properly tears down old connection when immediately reconnecting", function (){
      const connections = []
      const mockWebSocket = function StubWebSocketNoAutoClose(_url){
        const conn = {
          readyState: SOCKET_STATES.open,
          get bufferedAmount(){ return 1 },
          binaryType: "arraybuffer",
          timeout: 20000,
          onopen: null,
          onerror: null,
          onmessage: null,
          onclose: null,
          close(_code, _reason){
            this.readyState = SOCKET_STATES.closing
            setTimeout(() => {
              this.readyState = SOCKET_STATES.closed
            }, 1000)
          },
          send(){},
        }
        connections.push(conn)
        return conn
      }

      jest.useFakeTimers()

      socket = new Socket("/socket", {
        heartbeatIntervalMs: 30000,
        heartbeatTimeoutMs: 30000,
        reconnectAfterMs: () => 10,
        transport: mockWebSocket
      })
      socket.connect()
      const originalConn = socket.conn

      // Disconnect triggers teardown, which waits for bufferedAmount to be zero or 2250ms,
      // then awaits SOCKET_STATES.closed before calling the callback.
      const disconnected = jest.fn()
      socket.disconnect(disconnected)

      // For now, the conn is still set.
      expect(socket.conn).toBeTruthy()

      // Advance time by > 2250ms, which means we are waiting for socket to transition to closed
      jest.advanceTimersByTime(3000)

      // Now we call connect, while the teardown is still running
      socket.connect()
      // By now, waitForSocketClosed should be done, but now there's a new conn!
      jest.advanceTimersByTime(3000)
      expect(socket.conn).not.toBe(originalConn)

      const openConns = connections.filter(c => c.readyState === SOCKET_STATES.open)
      expect(openConns.length).toBe(1)

      // Late teardown must not overwrite this.conn with null when it is already connB
      expect(socket.conn).not.toBeNull()

      // the original disconnected should have been called
      expect(disconnected).toHaveBeenCalled()

      jest.useRealTimers()
    })

    it("properly tears down old connection when disconnecting twice", function (){
      const connections = []
      const mockWebSocket = function StubWebSocketNoAutoClose(_url){
        const conn = {
          readyState: SOCKET_STATES.open,
          get bufferedAmount(){ return 1 },
          binaryType: "arraybuffer",
          timeout: 20000,
          onopen: null,
          onerror: null,
          onmessage: null,
          onclose: null,
          close(_code, _reason){
            this.readyState = SOCKET_STATES.closing
            setTimeout(() => {
              this.readyState = SOCKET_STATES.closed
            }, 1000)
          },
          send(){},
        }
        connections.push(conn)
        return conn
      }

      jest.useFakeTimers()

      socket = new Socket("/socket", {
        heartbeatIntervalMs: 30000,
        heartbeatTimeoutMs: 30000,
        reconnectAfterMs: () => 10,
        transport: mockWebSocket
      })
      socket.connect()

      const disconnected = jest.fn()
      socket.disconnect(disconnected)

      // For now, the conn is still set.
      expect(socket.conn).toBeTruthy()

      // Advance time by > 2250ms, which means we are waiting for socket to transition to closed
      jest.advanceTimersByTime(3000)

      // Now we call disconnect again, while the teardown is still running
      const disconnected2 = jest.fn()
      socket.disconnect(disconnected2)

      jest.advanceTimersByTime(10000)

      const openConns = connections.filter(c => c.readyState === SOCKET_STATES.open)
      expect(openConns.length).toBe(0)
      expect(socket.conn).toBeNull()

      // both disconnected functions should have been called
      expect(disconnected).toHaveBeenCalled()
      expect(disconnected2).toHaveBeenCalled()

      jest.useRealTimers()
    })
  })

  describe("connectionState", function (){
    beforeEach(function (){
      socket = new Socket("/socket")
    })

    it("defaults to closed", function (){
      expect(socket.connectionState()).toBe("closed")
    })

    it("returns closed if readyState unrecognized", function (){
      socket.connect()
      socket.conn.readyState = 5678
      expect(socket.connectionState()).toBe("closed")
    })

    it("returns connecting", function (){
      socket.connect()
      socket.conn.readyState = 0
      expect(socket.connectionState()).toBe("connecting")
      expect(socket.isConnected()).toBe(false)
    })

    it("returns open", function (){
      socket.connect()
      socket.conn.readyState = 1
      expect(socket.connectionState()).toBe("open")
      expect(socket.isConnected()).toBe(true)
    })

    it("returns closing", function (){
      socket.connect()
      socket.conn.readyState = 2
      expect(socket.connectionState()).toBe("closing")
      expect(socket.isConnected()).toBe(false)
    })

    it("returns closed", function (){
      socket.connect()
      socket.conn.readyState = 3
      expect(socket.connectionState()).toBe("closed")
      expect(socket.isConnected()).toBe(false)
    })
  })

  describe("channel", function (){
    let channel

    beforeEach(function (){
      socket = new Socket("/socket")
    })

    it("returns channel with given topic and params", function (){
      channel = socket.channel("topic", {one: "two"})
      expect(channel.socket).toBe(socket)
      expect(channel.topic).toBe("topic")
      expect(channel.params()).toEqual({one: "two"})
    })

    it("adds channel to sockets channels list", function (){
      expect(socket.channels.length).toBe(0)
      channel = socket.channel("topic", {one: "two"})
      expect(socket.channels.length).toBe(1)
      const [foundChannel] = socket.channels
      expect(foundChannel).toBe(channel)
    })
  })

  describe("remove", function (){
    it("removes given channel from channels", function (){
      socket = new Socket("/socket")
      const channel1 = socket.channel("topic-1")
      const channel2 = socket.channel("topic-2")

      jest.spyOn(channel1, "joinRef").mockReturnValue(1)
      jest.spyOn(channel2, "joinRef").mockReturnValue(2)

      expect(socket.stateChangeCallbacks.open.length).toBe(2)

      socket.remove(channel1)

      expect(socket.stateChangeCallbacks.open.length).toBe(1)
      expect(socket.channels.length).toBe(1)

      const [foundChannel] = socket.channels
      expect(foundChannel).toBe(channel2)
    })
  })

  describe("push", function (){
    let data, json

    beforeEach(function (){
      data = {topic: "topic", event: "event", payload: "payload", ref: "ref"}
      json = encode(data)
      socket = new Socket("/socket")
    })

    it("sends data to connection when connected", function (){
      socket.connect()
      socket.conn.readyState = 1 // open

      const sendSpy = jest.spyOn(socket.conn, "send")

      socket.push(data)

      expect(sendSpy).toHaveBeenCalledWith(json)
    })

    it("buffers data when not connected", function (){
      socket.connect()
      socket.conn.readyState = 0 // connecting

      const sendSpy = jest.spyOn(socket.conn, "send").mockImplementation(() => {})

      expect(socket.sendBuffer.length).toBe(0)

      socket.push(data)

      expect(sendSpy).not.toHaveBeenCalledWith(json)
      expect(socket.sendBuffer.length).toBe(1)

      const [callback] = socket.sendBuffer
      callback()
      expect(sendSpy).toHaveBeenCalledWith(json)
    })
  })

  describe("makeRef", function (){
    beforeEach(function (){
      socket = new Socket("/socket")
    })

    it("returns next message ref", function (){
      expect(socket.ref).toBe(0)
      expect(socket.makeRef()).toBe("1")
      expect(socket.ref).toBe(1)
      expect(socket.makeRef()).toBe("2")
      expect(socket.ref).toBe(2)
    })

    it("restarts for overflow", function (){
      socket.ref = Number.MAX_SAFE_INTEGER + 1
      expect(socket.makeRef()).toBe("0")
      expect(socket.ref).toBe(0)
    })
  })

  describe("sendHeartbeat", function (){
    beforeEach(function (){
      socket = new Socket("/socket")
      socket.connect()
    })

    it("closes socket when heartbeat is not ack'd within heartbeat window", function (done){
      jest.useFakeTimers()
      let closed = false
      socket.conn.readyState = 1 // open
      socket.conn.close = () => closed = true
      socket.sendHeartbeat()
      expect(closed).toBe(false)

      jest.advanceTimersByTime(10000)
      expect(closed).toBe(false)

      jest.advanceTimersByTime(20010)
      expect(closed).toBe(true)

      jest.useRealTimers()
      done()
    })

    it("pushes heartbeat data when connected", function (){
      socket.conn.readyState = 1 // open

      const sendSpy = jest.spyOn(socket.conn, "send")
      const data = "[null,\"1\",\"phoenix\",\"heartbeat\",{}]"

      socket.sendHeartbeat()
      expect(sendSpy).toHaveBeenCalledWith(data)
    })

    it("no ops when not connected", function (){
      socket.conn.readyState = 0 // connecting

      const sendSpy = jest.spyOn(socket.conn, "send")
      const data = encode({topic: "phoenix", event: "heartbeat", payload: {}, ref: "1"})

      socket.sendHeartbeat()
      expect(sendSpy).not.toHaveBeenCalledWith(data)
    })
  })

  describe("flushSendBuffer", function (){
    beforeEach(function (){
      socket = new Socket("/socket")
      socket.connect()
    })

    it("calls callbacks in buffer when connected", function (){
      socket.conn.readyState = 1 // open
      const spy1 = jest.fn()
      const spy2 = jest.fn()
      socket.sendBuffer.push(spy1)
      socket.sendBuffer.push(spy2)

      socket.flushSendBuffer()

      expect(spy1).toHaveBeenCalledTimes(1)
      expect(spy2).toHaveBeenCalledTimes(1)
    })

    it("empties sendBuffer", function (){
      socket.conn.readyState = 1 // open
      socket.sendBuffer.push(() => { })

      socket.flushSendBuffer()

      expect(socket.sendBuffer.length).toBe(0)
    })
  })

  describe("onConnOpen", function (){
    let mockServer

    beforeAll(function (){
      mockServer = new WebSocketServer("wss://example.com/")
    })

    afterAll(function (done){
      mockServer.stop(() => done())
    })

    beforeEach(function (){
      socket = new Socket("/socket", {
        reconnectAfterMs: () => 100000
      })
      socket.connect()
    })

    it("flushes the send buffer", function (){
      socket.conn.readyState = 1 // open
      const spy = jest.fn()
      socket.sendBuffer.push(spy)

      socket.onConnOpen()

      expect(spy).toHaveBeenCalledTimes(1)
    })

    it("resets reconnectTimer", function (){
      const resetSpy = jest.spyOn(socket.reconnectTimer, "reset")
      socket.onConnOpen()
      expect(resetSpy).toHaveBeenCalledTimes(1)
    })

    it("triggers onOpen callback", function (){
      const spy = jest.fn()
      socket.onOpen(spy)
      socket.onConnOpen()
      expect(spy).toHaveBeenCalledTimes(1)
    })
  })

  describe("onConnClose", function (){
    let mockServer

    beforeAll(function (){
      mockServer = new WebSocketServer("wss://example.com/")
    })

    afterAll(function (done){
      mockServer.stop(() => done())
    })

    beforeEach(function (){
      socket = new Socket("/socket", {
        reconnectAfterMs: () => 100000
      })
      socket.connect()
    })

    it("does not schedule reconnectTimer if normal close", function (){
      const scheduleSpy = jest.spyOn(socket.reconnectTimer, "scheduleTimeout")
      const event = {code: 1000}
      socket.onConnClose(event)
      expect(scheduleSpy).not.toHaveBeenCalled()
    })

    it("schedules reconnectTimer timeout if abnormal close", function (){
      const scheduleSpy = jest.spyOn(socket.reconnectTimer, "scheduleTimeout")
      const event = {code: 1006}
      socket.onConnClose(event)
      expect(scheduleSpy).toHaveBeenCalledTimes(1)
    })

    it("does not schedule reconnectTimer timeout if normal close after explicit disconnect", function (){
      const scheduleSpy = jest.spyOn(socket.reconnectTimer, "scheduleTimeout")
      socket.disconnect()
      expect(scheduleSpy).not.toHaveBeenCalled()
    })

    it("schedules reconnectTimer timeout if not normal close", function (){
      const scheduleSpy = jest.spyOn(socket.reconnectTimer, "scheduleTimeout")
      const event = {code: 1001}
      socket.onConnClose(event)
      expect(scheduleSpy).toHaveBeenCalledTimes(1)
    })

    it("schedules reconnectTimer timeout if connection cannot be made after a previous clean disconnect", function (done){
      const scheduleSpy = jest.spyOn(socket.reconnectTimer, "scheduleTimeout")
      socket.disconnect(() => {
        socket.connect()
        const event = {code: 1001}
        socket.onConnClose(event)
        expect(scheduleSpy).toHaveBeenCalledTimes(1)
        done()
      })
    })

    it("triggers onClose callback", function (){
      const spy = jest.fn()
      socket.onClose(spy)
      socket.onConnClose("event")
      expect(spy).toHaveBeenCalledWith("event")
    })

    it("triggers channel error if joining", function (){
      const channel = socket.channel("topic")
      const triggerSpy = jest.spyOn(channel, "trigger")
      channel.join()
      expect(channel.state).toBe("joining")
      socket.onConnClose()
      expect(triggerSpy).toHaveBeenCalledWith("phx_error")
    })

    it("triggers channel error if joined", function (){
      const channel = socket.channel("topic")
      const triggerSpy = jest.spyOn(channel, "trigger")
      channel.join().trigger("ok", {})
      expect(channel.state).toBe("joined")
      socket.onConnClose()
      expect(triggerSpy).toHaveBeenCalledWith("phx_error")
    })

    it("does not trigger channel error after leave", function (){
      const channel = socket.channel("topic")
      const triggerSpy = jest.spyOn(channel, "trigger")
      channel.join().trigger("ok", {})
      channel.leave()
      expect(channel.state).toBe("closed")
      socket.onConnClose()
      expect(triggerSpy).not.toHaveBeenCalledWith("phx_error")
    })

    it("does not send heartbeat after explicit disconnect", function (done){
      jest.useFakeTimers()
      const sendHeartbeatSpy = jest.spyOn(socket, "sendHeartbeat")
      socket.onConnOpen()
      socket.disconnect()
      jest.advanceTimersByTime(30000)
      expect(sendHeartbeatSpy).not.toHaveBeenCalled()
      jest.useRealTimers()
      done()
    })

    it("does not timeout the heartbeat after explicit disconnect", function (done){
      jest.useFakeTimers()
      const heartbeatTimeoutSpy = jest.spyOn(socket, "heartbeatTimeout")
      socket.onConnOpen()
      socket.disconnect()
      jest.advanceTimersByTime(60000)
      expect(heartbeatTimeoutSpy).not.toHaveBeenCalled()
      jest.useRealTimers()
      done()
    })
  })

  describe("onConnError", function (){
    let mockServer

    beforeAll(function (){
      mockServer = new WebSocketServer("wss://example.com/")
    })

    afterAll(function (done){
      mockServer.stop(() => done())
    })

    beforeEach(function (){
      socket = new Socket("/socket", {
        reconnectAfterMs: () => 100000
      })
      socket.connect()
    })

    it("triggers onClose callback", function (){
      const spy = jest.fn()
      socket.onError(spy)
      socket.onConnError("error")
      expect(spy).toHaveBeenCalledWith("error", expect.any(Function), 0)
    })

    it("triggers channel error if joining with open connection", function (){
      const channel = socket.channel("topic")
      const triggerSpy = jest.spyOn(channel, "trigger")
      channel.join()
      socket.onConnOpen()
      expect(channel.state).toBe("joining")
      socket.onConnError("error")
      expect(triggerSpy).toHaveBeenCalledWith("phx_error")
    })

    it("triggers channel error if joining with no connection", function (){
      const channel = socket.channel("topic")
      const triggerSpy = jest.spyOn(channel, "trigger")
      channel.join()
      expect(channel.state).toBe("joining")
      socket.onConnError("error")
      expect(triggerSpy).toHaveBeenCalledWith("phx_error")
    })

    it("triggers channel error if joined", function (){
      const channel = socket.channel("topic")
      const triggerSpy = jest.spyOn(channel, "trigger")
      channel.join().trigger("ok", {})
      socket.onConnOpen()
      expect(channel.state).toBe("joined")

      let connectionsCount = null
      let transport = null
      socket.onError((error, erroredTransport, conns) => {
        transport = erroredTransport
        connectionsCount = conns
      })

      socket.onConnError("error")

      expect(transport).toBe(WebSocket)
      expect(connectionsCount).toBe(1)
      expect(triggerSpy).toHaveBeenCalledWith("phx_error")
    })

    it("does not trigger channel error after leave", function (){
      const channel = socket.channel("topic")
      const triggerSpy = jest.spyOn(channel, "trigger")
      channel.join().trigger("ok", {})
      channel.leave()
      expect(channel.state).toBe("closed")
      socket.onConnError("error")
      expect(triggerSpy).not.toHaveBeenCalledWith("phx_error")
    })

    it("does not trigger channel error if transport replaced with no previous connection", function (){
      const channel = socket.channel("topic")
      const triggerSpy = jest.spyOn(channel, "trigger")
      channel.join()
      expect(channel.state).toBe("joining")

      let connectionsCount = null
      class FakeTransport { }

      socket.onError((error, transport, conns) => {
        socket.replaceTransport(FakeTransport)
        connectionsCount = conns
      })
      socket.onConnError("error")

      expect(connectionsCount).toBe(0)
      expect(socket.transport).toBe(FakeTransport)
      expect(triggerSpy).not.toHaveBeenCalledWith("phx_error")
    })
  })

  describe("onConnMessage", function (){
    let mockServer

    beforeAll(function (){
      mockServer = new WebSocketServer("wss://example.com/")
    })

    afterAll(function (done){
      mockServer.stop(() => done())
    })

    beforeEach(function (){
      socket = new Socket("/socket", {
        reconnectAfterMs: () => 100000
      })
      socket.connect()
    })

    it("parses raw message and triggers channel event", function (){
      const message = encode({topic: "topic", event: "event", payload: "payload", ref: "ref"})
      const data = {data: message}

      const targetChannel = socket.channel("topic")
      const otherChannel = socket.channel("off-topic")

      const targetSpy = jest.spyOn(targetChannel, "trigger")
      const otherSpy = jest.spyOn(otherChannel, "trigger")

      socket.onConnMessage(data)

      expect(targetSpy).toHaveBeenCalledWith("event", "payload", "ref", null)
      expect(targetSpy).toHaveBeenCalledTimes(1)
      expect(otherSpy).toHaveBeenCalledTimes(0)
    })

    it("triggers onMessage callback", function (){
      const message = {"topic": "topic", "event": "event", "payload": "payload", "ref": "ref"}
      const spy = jest.fn()
      socket.onMessage(spy)
      socket.onConnMessage({data: encode(message)})

      expect(spy).toHaveBeenCalledWith({
        "topic": "topic",
        "event": "event",
        "payload": "payload",
        "ref": "ref",
        "join_ref": null
      })
    })
  })

  describe("ping", function (){
    beforeEach(function (){
      socket = new Socket("/socket")
      socket.connect()
    })

    it("pushes when connected", function (done){
      let latency = 100
      socket.conn.readyState = 1 // open
      expect(socket.isConnected()).toBe(true)
      socket.push = (msg) => {
        setTimeout(() => {
          socket.onConnMessage({data: encode({topic: "phoenix", event: "phx_reply", ref: msg.ref})})
        }, latency)
      }

      const result = socket.ping(rtt => {
        // if we're unlucky we could also receive 99 as rtt, so let's be generous
        expect(rtt >= (latency - 10)).toBe(true)
        done()
      })
      expect(result).toBe(true)
    })

    it("returns false when disconnected", function (){
      socket.conn.readyState = 0
      expect(socket.isConnected()).toBe(false)
      const result = socket.ping(_rtt => true)
      expect(result).toBe(false)
    })
  })

  describe("custom encoder and decoder", function (){

    it("encodes to JSON array by default", function (){
      socket = new Socket("/socket")
      const payload = {topic: "topic", ref: "2", join_ref: "1", event: "join", payload: {foo: "bar"}}

      socket.encode(payload, encoded => {
        expect(encoded).toBe("[\"1\",\"2\",\"topic\",\"join\",{\"foo\":\"bar\"}]")
      })
    })

    it("allows custom encoding when using WebSocket transport", function (){
      const encoder = (payload, callback) => callback("encode works")
      socket = new Socket("/socket", {transport: WebSocket, encode: encoder})

      socket.encode({foo: "bar"}, encoded => {
        expect(encoded).toBe("encode works")
      })
    })

    it("forces JSON encoding when using LongPoll transport", function (){
      const encoder = (payload, callback) => callback("encode works")
      socket = new Socket("/socket", {transport: LongPoll, encode: encoder})
      const payload = {topic: "topic", ref: "2", join_ref: "1", event: "join", payload: {foo: "bar"}}

      socket.encode(payload, encoded => {
        expect(encoded).toBe("[\"1\",\"2\",\"topic\",\"join\",{\"foo\":\"bar\"}]")
      })
    })

    it("decodes JSON by default", function (){
      socket = new Socket("/socket")
      const encoded = "[\"1\",\"2\",\"topic\",\"join\",{\"foo\":\"bar\"}]"

      socket.decode(encoded, decoded => {
        expect(decoded).toEqual({topic: "topic", ref: "2", join_ref: "1", event: "join", payload: {foo: "bar"}})
      })
    })

    it("allows custom decoding when using WebSocket transport", function (){
      const decoder = (payload, callback) => callback("decode works")
      socket = new Socket("/socket", {transport: WebSocket, decode: decoder})

      socket.decode("...esoteric format...", decoded => {
        expect(decoded).toBe("decode works")
      })
    })

    it("forces JSON decoding when using LongPoll transport", function (){
      const decoder = (payload, callback) => callback("decode works")
      socket = new Socket("/socket", {transport: LongPoll, decode: decoder})
      const payload = {topic: "topic", ref: "2", join_ref: "1", event: "join", payload: {foo: "bar"}}

      socket.decode("[\"1\",\"2\",\"topic\",\"join\",{\"foo\":\"bar\"}]", decoded => {
        expect(decoded).toEqual(payload)
      })
    })
  })
})

window.XMLHttpRequest = jest.fn()
window.WebSocket = WebSocket
