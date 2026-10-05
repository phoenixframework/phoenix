import {jest} from "@jest/globals"
import {WebSocket, Server as WebSocketServer} from "mock-socket"
import {encode} from "./serializer"
import {Socket, LongPoll} from "../js/phoenix"
import {AUTH_TOKEN_PREFIX, SOCKET_STATES} from "../js/phoenix/constants"

let socket

// connections created by the StubWebSocket, reset before using it
let connections

// a WebSocket that only opens and finishes its closing handshake when the test tells it to
class StubWebSocket {
  constructor(){
    this.readyState = SOCKET_STATES.connecting
    this.sent = []
    connections.push(this)
  }
  send(data){ this.sent.push(JSON.parse(data)) }
  close(){
    if(this.readyState !== SOCKET_STATES.closed){ this.readyState = SOCKET_STATES.closing }
  }
  open(){
    this.readyState = SOCKET_STATES.open
    this.onopen()
  }
  finishClose(code){
    this.readyState = SOCKET_STATES.closed
    this.onclose({code})
  }
}

const sentJoins = conn => conn.sent.filter(([, , topic, event]) => topic === "topic" && event === "phx_join")

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

      it("ignores the close of an open primary transport when falling back", function (done){
        class StubWebSocket {
          constructor(){ this.readyState = SOCKET_STATES.connecting }
          send(){ }
          close(){ this.readyState = SOCKET_STATES.closed }
        }
        window.sessionStorage.removeItem("phx:fallback:LongPoll")
        socket = new Socket("/socket", {longPollFallbackMs: 20, transport: StubWebSocket})
        const closeSpy = jest.fn()
        socket.onClose(closeSpy)
        const channel = socket.channel("topic")
        channel.join()
        const triggerSpy = jest.spyOn(channel, "trigger")

        socket.connect()
        const ws = socket.conn
        ws.readyState = SOCKET_STATES.open
        ws.onopen()
        const reconnectSpy = jest.spyOn(socket.reconnectTimer, "scheduleTimeout")

        // the health check ping never gets a reply, so we fall back while the websocket is open
        setTimeout(() => {
          expect(socket.transport).toBe(LongPoll)
          const longpoll = socket.conn
          expect(longpoll).toBeInstanceOf(LongPoll)
          expect(triggerSpy).toHaveBeenCalledWith("phx_error", {
            source: "transport",
            reason: "connection_closed"
          })

          // the websocket close event arrives after the longpoll transport was created
          const longpollOnClose = longpoll.onclose
          ws.onclose({code: 1000})

          expect(closeSpy).not.toHaveBeenCalled()
          expect(reconnectSpy).not.toHaveBeenCalled()
          expect(socket.conn).toBe(longpoll)
          expect(longpoll.onclose).toBe(longpollOnClose)
          done()
        }, 50)
      })

      describe("across connection attempts", function (){
        beforeEach(function (){
          connections = []
          jest.useFakeTimers()
          Object.defineProperty(document, "visibilityState", {value: "visible", writable: true})
          window.sessionStorage.removeItem("phx:fallback:LongPoll")
          socket = new Socket("/socket", {transport: StubWebSocket, longPollFallbackMs: 2500, reconnectAfterMs: () => 10})
        })

        afterEach(function (){
          jest.useRealTimers()
        })

        it("does not accumulate error callbacks", function (){
          socket.connect()
          for(let i = 0; i < 3; i++){
            connections[i].open()
            // the connection drops and the socket reconnects
            connections[i].finishClose(1006)
            jest.advanceTimersByTime(10)
          }

          expect(connections.length).toBe(4)
          expect(socket.stateChangeCallbacks.error.length).toBe(1)
        })

        it("falls back once when a previous attempt failed without an error", function (){
          const replaceSpy = jest.spyOn(socket, "replaceTransport")
          socket.connect()
          connections[0].finishClose(1006)
          jest.advanceTimersByTime(10)

          connections[1].onerror("error")

          expect(replaceSpy).toHaveBeenCalledTimes(1)
        })

        it("does not fall back after a normal close", function (){
          socket.connect()
          connections[0].open()
          // a normal close also cancels a reconnect that was already scheduled
          socket.reconnectTimer.scheduleTimeout()

          connections[0].finishClose(1000)
          jest.advanceTimersByTime(5000)

          expect(socket.transport).toBe(StubWebSocket)
          expect(connections.length).toBe(1)
          expect(socket.closeWasClean).toBe(true)
          expect(socket.stateChangeCallbacks.open.length).toBe(0)
          expect(socket.stateChangeCallbacks.error.length).toBe(0)
        })

        it("remembers LongPoll when a later fallback connection opens", function (){
          socket.connect()
          jest.advanceTimersByTime(2500)
          const firstLongpoll = socket.conn
          expect(firstLongpoll).toBeInstanceOf(LongPoll)
          expect(socket.getSession("phx:fallback:LongPoll")).toBeNull()

          firstLongpoll.close(1011, "internal server error", false)
          jest.advanceTimersByTime(10)
          const secondLongpoll = socket.conn
          expect(secondLongpoll).not.toBe(firstLongpoll)
          secondLongpoll.readyState = SOCKET_STATES.open
          secondLongpoll.onopen({})

          expect(socket.getSession("phx:fallback:LongPoll")).toBe("true")
        })

        it("does not remember fallback when an earlier onOpen callback disconnects", function (){
          socket.onOpen(() => socket.disconnect())
          socket.connect()
          jest.advanceTimersByTime(2500)
          const longpoll = socket.conn
          longpoll.readyState = SOCKET_STATES.open
          longpoll.onopen({})

          expect(socket.getSession("phx:fallback:LongPoll")).toBeNull()
          expect(socket.conn).toBeNull()
        })

        it("does not rearm fallback when an earlier onOpen callback disconnects", function (){
          socket.onOpen(() => socket.disconnect())
          socket.connect()

          connections[0].open()
          jest.advanceTimersByTime(5000)

          expect(socket.transport).toBe(StubWebSocket)
          expect(connections.length).toBe(1)
          expect(socket.conn).toBeNull()
        })

        it("does not fall back when an earlier onError callback disconnects", function (){
          socket.onError(() => socket.disconnect())
          socket.connect()

          connections[0].onerror("error")
          jest.advanceTimersByTime(5000)

          expect(socket.transport).toBe(StubWebSocket)
          expect(connections.length).toBe(1)
          expect(socket.conn).toBeNull()
        })

        it("does not connect fallback when a channel error callback disconnects", function (){
          socket.connect()
          connections[0].open()
          const channel = socket.channel("topic")
          channel.join().trigger("ok", {})
          channel.onError(() => socket.disconnect())

          jest.advanceTimersByTime(2500)

          expect(socket.conn).toBeNull()
          expect(socket.closeWasClean).toBe(true)
          expect(socket.transport).toBe(StubWebSocket)
          expect(connections.length).toBe(1)
        })

        it("keeps a connection created by a channel error callback during fallback", function (){
          socket.connect()
          connections[0].open()
          const channel = socket.channel("topic")
          channel.join().trigger("ok", {})
          const errorRef = channel.onError(() => {
            channel.off("phx_error", errorRef)
            socket.connect()
          })

          jest.advanceTimersByTime(2500)

          expect(socket.conn).toBe(connections[1])
          expect(socket.transport).toBe(StubWebSocket)
          expect(connections.length).toBe(2)
          connections[1].open()
          expect(sentJoins(connections[1]).length).toBe(1)
        })
      })
    })
  })

  describe("visibilitychange", function (){
    it("does not connect a socket that was never connected", function (){
      socket = new Socket("/socket")
      const teardownSpy = jest.spyOn(socket, "teardown")

      Object.defineProperty(document, "visibilityState", {value: "hidden", writable: true})
      window.dispatchEvent(new Event("visibilitychange"))

      Object.defineProperty(document, "visibilityState", {value: "visible", writable: true})
      window.dispatchEvent(new Event("visibilitychange"))

      expect(teardownSpy).not.toHaveBeenCalled()
    })

    it("reconnects on visibility change after unclean close", function (){
      socket = new Socket("/socket")
      socket.closeWasClean = false
      const teardownSpy = jest.spyOn(socket, "teardown")

      Object.defineProperty(document, "visibilityState", {value: "visible", writable: true})
      window.dispatchEvent(new Event("visibilitychange"))

      expect(teardownSpy).toHaveBeenCalledTimes(1)
    })

    it("does not reconnect on visibility change after clean close", function (){
      socket = new Socket("/socket")
      socket.closeWasClean = true
      const teardownSpy = jest.spyOn(socket, "teardown")

      Object.defineProperty(document, "visibilityState", {value: "visible", writable: true})
      window.dispatchEvent(new Event("visibilitychange"))

      expect(teardownSpy).not.toHaveBeenCalled()
    })
  })

  describe("resume", function (){
    // Chrome does not reliably fire visibilitychange when a frozen page is
    // resumed, see https://issues.chromium.org/issues/547062449.
    it("reconnects on resume after unclean close", function (){
      socket = new Socket("/socket")
      socket.closeWasClean = false
      const teardownSpy = jest.spyOn(socket, "teardown")

      Object.defineProperty(document, "visibilityState", {value: "visible", writable: true})
      document.dispatchEvent(new Event("resume"))

      expect(teardownSpy).toHaveBeenCalledTimes(1)
    })

    it("does not reconnect on resume while the page is still hidden", function (){
      socket = new Socket("/socket")
      socket.closeWasClean = false
      const teardownSpy = jest.spyOn(socket, "teardown")

      Object.defineProperty(document, "visibilityState", {value: "hidden", writable: true})
      document.dispatchEvent(new Event("resume"))

      expect(teardownSpy).not.toHaveBeenCalled()
    })

    it("does not reconnect on resume after clean close", function (){
      socket = new Socket("/socket")
      socket.closeWasClean = true
      const teardownSpy = jest.spyOn(socket, "teardown")

      Object.defineProperty(document, "visibilityState", {value: "visible", writable: true})
      document.dispatchEvent(new Event("resume"))

      expect(teardownSpy).not.toHaveBeenCalled()
    })

    describe("after the connection dropped", function (){
      beforeEach(function (){
        connections = []
        jest.useFakeTimers()
        Object.defineProperty(document, "visibilityState", {value: "visible", writable: true})
        socket = new Socket("/socket", {transport: StubWebSocket, reconnectAfterMs: () => 10})
        socket.connect()
        connections[0].open()
        // schedules a reconnect
        connections[0].finishClose(1006)
      })

      afterEach(function (){
        jest.useRealTimers()
      })

      it("does not let the scheduled reconnect replace the new connection", function (){
        socket.handleVisibilityChange()
        jest.advanceTimersByTime(5000)

        expect(connections.length).toBe(2)
        expect(socket.conn).toBe(connections[1])
        expect(connections[1].readyState).toBe(SOCKET_STATES.connecting)
      })

      it("keeps the new connection when visibilitychange follows resume", function (){
        socket.handleVisibilityChange()
        socket.handleVisibilityChange()
        jest.advanceTimersByTime(5000)

        expect(connections.length).toBe(2)
        expect(socket.conn).toBe(connections[1])
        expect(connections[1].readyState).toBe(SOCKET_STATES.connecting)
      })

      it("replaces a connection that is still connecting after the page was hidden again", function (){
        socket.handleVisibilityChange()

        Object.defineProperty(document, "visibilityState", {value: "hidden", writable: true})
        socket.handleVisibilityChange()
        Object.defineProperty(document, "visibilityState", {value: "visible", writable: true})
        socket.handleVisibilityChange()
        jest.advanceTimersByTime(5000)

        expect(connections.length).toBe(3)
        expect(socket.conn).toBe(connections[2])
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

    it("uses updated authToken function value when reconnecting", function (){
      jest.useFakeTimers()

      try {
        let authToken = "old-token"
        const connections = []
        class ReconnectingWebSocket {
          constructor(_url, protocols){
            this.protocols = protocols
            this.readyState = SOCKET_STATES.open
            this.bufferedAmount = 0
            connections.push(this)
          }
          close(){ this.readyState = SOCKET_STATES.closed }
          send(){}
        }

        socket = new Socket("/socket", {
          transport: ReconnectingWebSocket,
          authToken: () => authToken,
          reconnectAfterMs: () => 10
        })

        socket.connect()
        authToken = "new-token"
        socket.onConnClose({code: 1006})
        jest.advanceTimersByTime(10)

        expect(connections.length).toBe(2)
        expect(connections[0].protocols).toEqual(["phoenix", `${AUTH_TOKEN_PREFIX}${btoa("old-token").replace(/=/g, "")}`])
        expect(connections[1].protocols).toEqual(["phoenix", `${AUTH_TOKEN_PREFIX}${btoa("new-token").replace(/=/g, "")}`])
        expect(socket.conn).toBe(connections[1])
      } finally {
        jest.useRealTimers()
      }
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

    describe("when the close event is delayed", function (){
      beforeEach(function (){
        connections = []
        jest.useFakeTimers()
        socket = new Socket("/socket", {transport: StubWebSocket})
        socket.connect()
      })

      afterEach(function (){
        jest.useRealTimers()
      })

      it("rejoins channels on the next connection after teardown stopped waiting", function (){
        connections[0].open()
        const channel = socket.channel("topic")
        channel.join().trigger("ok", {})

        socket.disconnect()
        jest.advanceTimersByTime(2000)
        expect(socket.conn).toBeNull()

        socket.connect()
        connections[1].open()

        expect(channel.state).toBe("joining")
        expect(sentJoins(connections[1]).length).toBe(1)
      })

      it("rejoins channels when connecting again before the old connection closed", function (){
        connections[0].open()
        const channel = socket.channel("topic")
        channel.join().trigger("ok", {})

        socket.disconnect()
        socket.connect()
        connections[1].open()

        expect(channel.state).toBe("joining")
        expect(sentJoins(connections[1]).length).toBe(1)
      })

      describe("while the buffer of the old connection drains", function (){
        beforeEach(function (){
          connections[0].open()
          connections[0].bufferedAmount = 1
        })

        it("does not error a later channel rejoined by an earlier error callback", function (){
          const first = socket.channel("first")
          const second = socket.channel("second")
          first.join().trigger("ok", {})
          second.join().trigger("ok", {})
          let replacementJoinRef
          first.onError(() => {
            second.rejoin()
            replacementJoinRef = second.joinRef()
          })

          socket.disconnect()
          socket.connect()
          connections[1].open()
          connections[0].bufferedAmount = 0
          jest.advanceTimersByTime(150)

          expect(second.state).toBe("joining")
          expect(second.joinRef()).toBe(replacementJoinRef)
          second.joinPush.trigger("ok", {})
          expect(second.state).toBe("joined")
        })

        it("does not error channels that already rejoined on the new connection", function (){
          const channel = socket.channel("topic")
          channel.join().trigger("error", {})
          socket.disconnect()
          socket.connect()
          connections[1].open()
          channel.joinPush.trigger("ok", {})

          jest.advanceTimersByTime(2000)

          expect(connections[0].readyState).toBe(SOCKET_STATES.closing)
          expect(channel.state).toBe("joined")
        })

        it("rejoins channels that were joined over the old connection", function (){
          const channel = socket.channel("topic")
          channel.join().trigger("ok", {})
          socket.disconnect()
          socket.connect()
          connections[1].open()

          jest.advanceTimersByTime(2000)

          expect(channel.state).toBe("errored")
          jest.advanceTimersByTime(socket.rejoinAfterMs(1))
          expect(sentJoins(connections[1]).length).toBe(1)
        })

        it("rejoins channels that joined over the old connection while it drained", function (){
          socket.disconnect()
          const channel = socket.channel("topic")
          channel.join()
          expect(sentJoins(connections[0]).length).toBe(1)

          jest.advanceTimersByTime(2000)
          socket.connect()
          connections[1].open()

          expect(sentJoins(connections[1]).length).toBe(1)
        })

        it("rejoins a new channel that joined while draining before its conn was replaced", function (){
          socket.disconnect()
          const channel = socket.channel("topic")
          channel.join().trigger("ok", {})
          expect(sentJoins(connections[0]).length).toBe(1)
          socket.connect()
          connections[1].open()

          jest.advanceTimersByTime(2000)

          expect(channel.state).toBe("errored")
          jest.advanceTimersByTime(socket.rejoinAfterMs(1))
          expect(sentJoins(connections[1]).length).toBe(1)
        })

        it("rejoins a channel that rejoined on the old conn while it drained", function (){
          const channel = socket.channel("topic")
          channel.join().trigger("error", {})
          socket.disconnect()
          jest.advanceTimersByTime(socket.rejoinAfterMs(1))
          channel.joinPush.trigger("ok", {})
          expect(sentJoins(connections[0]).length).toBe(2)
          socket.connect()
          connections[1].open()

          jest.advanceTimersByTime(1000)

          expect(channel.state).toBe("errored")
          jest.advanceTimersByTime(socket.rejoinAfterMs(1))
          expect(sentJoins(connections[1]).length).toBe(1)
        })

        it("does not error a channel whose rejoin is buffered for the new conn", function (){
          const channel = socket.channel("topic")
          channel.join().trigger("ok", {})
          socket.disconnect()
          socket.connect()
          channel.trigger("phx_error", {})
          channel.rejoin()
          const joinRef = channel.joinRef()

          jest.advanceTimersByTime(2000)
          connections[1].open()

          expect(channel.joinRef()).toBe(joinRef)
          expect(sentJoins(connections[1]).map(([ref]) => ref)).toEqual([joinRef])
        })
      })

      it("does not replace the new connection when connecting again before the old one closed", function (){
        connections[0].open()

        socket.disconnect()
        socket.connect()
        socket.connect()

        expect(connections.length).toBe(2)
        expect(socket.conn).toBe(connections[1])
      })

      it("does not let an old teardown clear a newer disconnect", function (){
        connections[0].open()
        const firstDisconnected = jest.fn()
        const secondDisconnected = jest.fn()
        socket.disconnect(firstDisconnected)
        socket.connect()
        connections[1].open()
        connections[1].bufferedAmount = 1
        socket.disconnect(secondDisconnected)

        connections[0].finishClose(1000)
        jest.advanceTimersByTime(150)

        expect(firstDisconnected).toHaveBeenCalledTimes(1)
        expect(secondDisconnected).not.toHaveBeenCalled()
        expect(socket.connection.ended).toBe(true)
        socket.connect()
        expect(connections.length).toBe(3)
        expect(socket.conn).toBe(connections[2])
        connections[1].bufferedAmount = 0
        connections[1].finishClose(1000)
        jest.advanceTimersByTime(300)
        expect(secondDisconnected).toHaveBeenCalledTimes(1)
        expect(socket.conn).toBe(connections[2])
      })

      describe("when a channel error callback joins another channel", function (){
        let other, otherErrors

        beforeEach(function (){
          connections[0].open()
          const channel = socket.channel("topic")
          channel.join().trigger("ok", {})
          other = null
          otherErrors = jest.fn()
          channel.onError(() => {
            if(other){ return }
            other = socket.channel("other")
            other.join()
            other.onError(otherErrors)
          })
        })

        // the join of the other channel is buffered and sent once the next connection opens
        const expectOtherJoinedOnNextConnection = (joinRef) => {
          const conn = connections[connections.length - 1]
          conn.open()
          expect(otherErrors).not.toHaveBeenCalled()
          expect(other.joinRef()).toBe(joinRef)
          expect(conn.sent.filter(([, , topic, event]) => topic === "other" && event === "phx_join").map(([ref]) => ref))
            .toEqual([joinRef])
        }

        it("does not error it again when the close event arrives during teardown", function (){
          socket.disconnect()
          const joinRef = other.joinRef()
          connections[0].finishClose(1000)
          jest.advanceTimersByTime(2000)
          socket.connect()

          expectOtherJoinedOnNextConnection(joinRef)
        })

        it("does not error it again when the close event is emitted synchronously", function (){
          connections[0].close = () => connections[0].finishClose(1000)
          socket.disconnect()
          const joinRef = other.joinRef()
          socket.connect()

          expectOtherJoinedOnNextConnection(joinRef)
        })

        it("does not error it again when a failed connection emits error before close", function (){
          connections[0].readyState = SOCKET_STATES.closed
          connections[0].onerror("error")
          const joinRef = other.joinRef()
          connections[0].onclose({code: 1006})
          jest.advanceTimersByTime(2000)

          expectOtherJoinedOnNextConnection(joinRef)
        })
      })

      it("errors channels after the connection stopped being connected", function (){
        connections[0].open()
        const channel = socket.channel("topic")
        channel.join().trigger("ok", {})
        const connectedOnError = []
        channel.onError(() => connectedOnError.push(socket.isConnected()))
        const rejoinSpy = jest.spyOn(channel.rejoinTimer, "scheduleTimeout")

        socket.disconnect()

        expect(connectedOnError).toEqual([false])
        expect(rejoinSpy).not.toHaveBeenCalled()
      })

      it("does not error channels when the connection never opened", function (){
        const channel = socket.channel("topic")
        channel.join()
        const errorSpy = jest.fn()
        channel.onError(errorSpy)

        socket.disconnect()
        jest.advanceTimersByTime(2000)
        socket.connect()
        connections[1].open()

        // the buffered join is sent once, without an additional rejoin
        expect(errorSpy).not.toHaveBeenCalled()
        expect(channel.state).toBe("joining")
        expect(sentJoins(connections[1]).length).toBe(1)
      })

      it("ignores the close event of a connection that was replaced", function (){
        connections[0].open()
        const channel = socket.channel("topic")
        channel.join().trigger("ok", {})
        socket.disconnect()
        socket.connect()
        connections[1].open()
        channel.joinPush.trigger("ok", {})
        const closeSpy = jest.fn()
        socket.onClose(closeSpy)
        const reconnectSpy = jest.spyOn(socket.reconnectTimer, "scheduleTimeout")

        connections[0].finishClose(1005)

        expect(closeSpy).not.toHaveBeenCalled()
        expect(reconnectSpy).not.toHaveBeenCalled()
        expect(channel.state).toBe("joined")
        expect(socket.isConnected()).toBe(true)

        // the close of the current connection is still handled
        connections[1].finishClose(1006)
        expect(closeSpy).toHaveBeenCalledTimes(1)
        expect(reconnectSpy).toHaveBeenCalledTimes(1)
        expect(channel.state).toBe("errored")
      })

      it("ignores errors and messages of a connection that was replaced", function (){
        connections[0].open()
        const channel = socket.channel("topic")
        channel.join().trigger("ok", {})
        // the old connection is not closed yet while its buffer drains
        connections[0].bufferedAmount = 1
        socket.disconnect()
        socket.connect()
        connections[1].open()
        channel.joinPush.trigger("ok", {})
        const errorSpy = jest.fn()
        socket.onError(errorSpy)
        const messageSpy = jest.fn()
        socket.onMessage(messageSpy)

        connections[0].onerror("error")
        connections[0].onmessage({data: encode({topic: "topic", event: "event", payload: {}})})

        expect(errorSpy).not.toHaveBeenCalled()
        expect(messageSpy).not.toHaveBeenCalled()
        expect(channel.state).toBe("joined")
      })

      it("does not error a replacement opened by an onError callback", function (){
        connections[0].open()
        const channel = socket.channel("topic")
        channel.join().trigger("ok", {})
        socket.onError(() => {
          socket.disconnect()
          socket.connect()
          connections[1].open()
          channel.joinPush.trigger("ok", {})
        })

        connections[0].onerror("error")

        expect(socket.conn).toBe(connections[1])
        expect(channel.state).toBe("joined")
      })

      it("rejoins channels when an onError callback replaces the transport of a failed connection", function (){
        connections[0].open()
        const channel = socket.channel("topic")
        channel.join().trigger("ok", {})
        socket.onError(() => socket.replaceTransport(StubWebSocket))

        // a WebSocket that failed is already closed when it emits its error
        connections[0].readyState = SOCKET_STATES.closed
        connections[0].onerror("error")
        socket.connect()
        connections[1].open()

        expect(sentJoins(connections[1]).length).toBe(1)
      })

      it("does not error channels created for a new connection by an onError callback", function (){
        connections[0].open()
        let channel
        socket.onError(() => {
          socket.disconnect()
          socket.connect()
          channel = socket.channel("fresh")
          channel.join()
        })

        connections[0].onerror("error")

        expect(channel.state).toBe("joining")
        connections[1].open()
        expect(connections[1].sent.filter(([, , topic, event]) => topic === "fresh" && event === "phx_join")).toHaveLength(1)
      })

      it("stops the heartbeat so that it does not reconnect the socket", function (){
        connections[0].open()

        socket.disconnect()
        jest.advanceTimersByTime(3 * socket.heartbeatIntervalMs)

        expect(connections.length).toBe(1)
        expect(socket.conn).toBeNull()
      })

      it("does not restart the heartbeat when its reply arrives while the buffer drains", function (){
        connections[0].open()
        jest.advanceTimersByTime(socket.heartbeatIntervalMs)
        const [[, heartbeatRef]] = connections[0].sent.filter(([, , topic]) => topic === "phoenix")
        connections[0].bufferedAmount = 1
        socket.disconnect()

        const reply = {ref: heartbeatRef, topic: "phoenix", event: "phx_reply", payload: {status: "ok", response: {}}}
        connections[0].onmessage({data: encode(reply)})
        jest.advanceTimersByTime(3 * socket.heartbeatIntervalMs)

        expect(connections.length).toBe(1)
        expect(socket.conn).toBeNull()
      })

      it("does not reconnect after a heartbeat timeout when disconnected meanwhile", function (){
        connections[0].open()
        // the heartbeat is sent and times out, so the connection is torn down
        jest.advanceTimersByTime(2 * socket.heartbeatIntervalMs)
        expect(connections[0].readyState).toBe(SOCKET_STATES.closing)

        socket.disconnect()
        jest.advanceTimersByTime(10000)

        expect(connections.length).toBe(1)
        expect(socket.conn).toBeNull()
      })

      it("does not reconnect after a visibility change when disconnected meanwhile", function (){
        Object.defineProperty(document, "visibilityState", {value: "visible", writable: true})
        // the connection is still connecting, so the visibility change tears it down
        socket.handleVisibilityChange()
        expect(connections[0].readyState).toBe(SOCKET_STATES.closing)

        socket.disconnect()
        jest.advanceTimersByTime(10000)

        expect(connections.length).toBe(1)
        expect(socket.conn).toBeNull()
      })

      it("does not reconnect after a visibility change when the transport was replaced meanwhile", function (){
        Object.defineProperty(document, "visibilityState", {value: "visible", writable: true})
        socket.handleVisibilityChange()

        socket.replaceTransport(StubWebSocket)
        jest.advanceTimersByTime(10000)

        expect(connections.length).toBe(1)
        expect(socket.conn).toBeNull()
      })

      it("does not fall back to LongPoll when disconnecting while connecting", function (){
        window.sessionStorage.removeItem("phx:fallback:LongPoll")
        socket = new Socket("/socket", {transport: StubWebSocket, longPollFallbackMs: 2500})
        const errorSpy = jest.fn()
        socket.onError(errorSpy)
        socket.connect()

        socket.disconnect()
        // browsers fail a connection that is closed while connecting with an error event
        connections[1].onerror("error")
        jest.advanceTimersByTime(10000)

        expect(socket.transport).toBe(StubWebSocket)
        expect(socket.conn).toBeNull()
        expect(connections.length).toBe(2)
        expect(errorSpy).not.toHaveBeenCalled()
      })
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
      socket.conn.readyState = SOCKET_STATES.open
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

  describe("buffered channel pushes", function (){
    beforeEach(function (){
      connections = []
      jest.useFakeTimers()
      Object.defineProperty(document, "visibilityState", {value: "visible", writable: true})
      socket = new Socket("/socket", {transport: StubWebSocket, reconnectAfterMs: () => 10})
      socket.connect()
    })

    afterEach(function (){
      jest.useRealTimers()
    })

    it("sends the join of a channel that is still joining", function (){
      const channel = socket.channel("topic")
      channel.join()

      connections[0].open()

      expect(sentJoins(connections[0]).map(([joinRef]) => joinRef)).toEqual([channel.joinRef()])
    })

    it("drops the join of a channel that errored, as its rejoin supersedes it", function (){
      const channel = socket.channel("topic")
      channel.join()
      // the connection fails before opening, so the join is still buffered
      connections[0].finishClose(1006)
      jest.advanceTimersByTime(10)

      connections[1].open()

      expect(sentJoins(connections[1]).map(([joinRef]) => joinRef)).toEqual([channel.joinRef()])
    })

    it("drops the pushes of a channel that left", function (){
      const channel = socket.channel("topic")
      channel.join()
      channel.leave()

      connections[0].open()

      expect(connections[0].sent.filter(([, , topic]) => topic === "topic")).toEqual([])
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

  describe("heartbeatTimeout", function (){
    it("triggers channel error with the heartbeat timeout reason", function (){
      socket = new Socket("/socket")
      const channel = socket.channel("topic")
      const triggerSpy = jest.spyOn(channel, "trigger")
      jest.spyOn(socket, "teardown").mockImplementation(() => {})

      channel.join().trigger("ok", {})
      socket.pendingHeartbeatRef = "1"
      socket.heartbeatTimeout()

      expect(triggerSpy).toHaveBeenCalledWith("phx_error", {
        source: "transport",
        reason: "heartbeat_timeout"
      })
    })

    describe("with a connection that does not respond", function (){
      let channel

      beforeEach(function (){
        connections = []
        jest.useFakeTimers()
        Object.defineProperty(document, "visibilityState", {value: "visible", writable: true})
        socket = new Socket("/socket", {transport: StubWebSocket, reconnectAfterMs: () => 10})
        socket.connect()
        connections[0].open()
        channel = socket.channel("topic")
        channel.join().trigger("ok", {})
        // the heartbeat is stuck in the buffer
        connections[0].bufferedAmount = 1
      })

      afterEach(function (){
        jest.useRealTimers()
      })

      it("errors channels after closing the connection", function (){
        const errors = []
        channel.onError(({reason}) => errors.push([reason, socket.isConnected()]))

        jest.advanceTimersByTime(2 * socket.heartbeatIntervalMs)

        expect(connections[0].readyState).toBe(SOCKET_STATES.closing)
        expect(errors).toEqual([["heartbeat_timeout", false]])
      })

      it("reconnects without waiting for the buffer to drain", function (){
        jest.advanceTimersByTime(2 * socket.heartbeatIntervalMs)

        // only waits for the close event, which never arrives
        jest.advanceTimersByTime(1500 + 10)

        expect(connections.length).toBe(2)
      })

      it("does not reconnect when a heartbeat error callback disconnects", function (){
        channel.onError(() => socket.disconnect())

        jest.advanceTimersByTime(2 * socket.heartbeatIntervalMs + 5000)

        expect(connections.length).toBe(1)
        expect(socket.conn).toBeNull()
      })

      it("keeps a replacement opened by a heartbeat error callback", function (){
        const errorRef = channel.onError(() => {
          channel.off("phx_error", errorRef)
          socket.disconnect()
          socket.connect()
          connections[1].open()
          channel.joinPush.trigger("ok", {})
        })

        jest.advanceTimersByTime(2 * socket.heartbeatIntervalMs + 5000)

        expect(connections.length).toBe(2)
        expect(socket.conn).toBe(connections[1])
        expect(socket.isConnected()).toBe(true)
        expect(channel.state).toBe("joined")
      })

      it("reconnects on visibility change after a synchronous heartbeat close while hidden", function (){
        connections[0].close = () => connections[0].finishClose(1000)
        Object.defineProperty(document, "visibilityState", {value: "hidden", writable: true})

        jest.advanceTimersByTime(2 * socket.heartbeatIntervalMs)

        // this must remain an unclean close before any reconnect can reset the flag
        expect(socket.closeWasClean).toBe(false)
        jest.advanceTimersByTime(10)
        expect(connections.length).toBe(1)
        expect(socket.conn).toBeNull()

        Object.defineProperty(document, "visibilityState", {value: "visible", writable: true})
        socket.handleVisibilityChange()

        expect(connections.length).toBe(2)
        expect(socket.conn).toBe(connections[1])
        expect(socket.closeWasClean).toBe(false)
      })

      it("keeps a replacement opened by a synchronous heartbeat close callback", function (){
        connections[0].close = () => connections[0].finishClose(1000)
        const closeRef = socket.onClose(() => {
          socket.off([closeRef])
          socket.disconnect()
          socket.connect()
          connections[1].open()
          channel.joinPush.trigger("ok", {})
        })

        jest.advanceTimersByTime(2 * socket.heartbeatIntervalMs + 5000)

        expect(connections.length).toBe(2)
        expect(socket.conn).toBe(connections[1])
        expect(socket.isConnected()).toBe(true)
        expect(channel.state).toBe("joined")
      })
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
      expect(triggerSpy).toHaveBeenCalledWith("phx_error", {
        source: "transport",
        reason: "connection_closed"
      })
    })

    it("triggers channel error if joined", function (){
      const channel = socket.channel("topic")
      const triggerSpy = jest.spyOn(channel, "trigger")
      channel.join().trigger("ok", {})
      expect(channel.state).toBe("joined")
      socket.onConnClose()
      expect(triggerSpy).toHaveBeenCalledWith("phx_error", {
        source: "transport",
        reason: "connection_closed"
      })
    })

    it("does not trigger channel error after leave", function (){
      const channel = socket.channel("topic")
      const triggerSpy = jest.spyOn(channel, "trigger")
      channel.join().trigger("ok", {})
      channel.leave()
      expect(channel.state).toBe("closed")
      socket.onConnClose()
      expect(triggerSpy.mock.calls.some(([event]) => event === "phx_error")).toBe(false)
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

    describe("when the server closes the connection", function (){
      beforeEach(function (){
        connections = []
        jest.useFakeTimers()
        Object.defineProperty(document, "visibilityState", {value: "visible", writable: true})
        socket = new Socket("/socket", {transport: StubWebSocket, reconnectAfterMs: () => 10})
        socket.connect()
        connections[0].open()
      })

      afterEach(function (){
        jest.useRealTimers()
      })

      it("does not error later channels rejoined by a close error callback", function (){
        const first = socket.channel("first")
        const second = socket.channel("second")
        first.join().trigger("ok", {})
        second.join().trigger("ok", {})
        first.onError(() => {
          socket.disconnect()
          socket.connect()
          connections[1].open()
          first.joinPush.trigger("ok", {})
          second.joinPush.trigger("ok", {})
        })

        connections[0].finishClose(1000)

        expect(first.state).toBe("joined")
        expect(second.state).toBe("joined")
      })

      it("does not reconnect on visibility change after a normal close", function (){
        connections[0].finishClose(1000)

        socket.handleVisibilityChange()
        jest.advanceTimersByTime(5000)

        expect(connections.length).toBe(1)
      })

      it("still reconnects on visibility change when the server only confirmed our close", function (){
        // the heartbeat times out, so we close the connection with 1000, which the server confirms
        jest.advanceTimersByTime(2 * socket.heartbeatIntervalMs)
        connections[0].finishClose(1000)
        // the page is hidden, so the scheduled reconnect is skipped
        Object.defineProperty(document, "visibilityState", {value: "hidden", writable: true})
        jest.advanceTimersByTime(5000)
        expect(connections.length).toBe(1)

        Object.defineProperty(document, "visibilityState", {value: "visible", writable: true})
        socket.handleVisibilityChange()

        expect(connections.length).toBe(2)
      })

      it("does not let a scheduled reconnect replace a connection created after a normal close", function (){
        socket.reconnectTimer.scheduleTimeout()
        connections[0].finishClose(1000)

        socket.connect()
        jest.advanceTimersByTime(5000)

        expect(connections.length).toBe(2)
        expect(socket.conn).toBe(connections[1])
      })

      it("connects again when asked to after a normal close", function (){
        connections[0].finishClose(1000)

        socket.connect()

        expect(connections.length).toBe(2)
        expect(socket.conn).toBe(connections[1])
      })

      it.each([1000, 1006])("preserves a connection opened by a channel error callback (close: %s)", function (code){
        const channel = socket.channel("topic")
        channel.join().trigger("ok", {})
        const errorRef = channel.onError(() => {
          channel.off("phx_error", errorRef)
          socket.disconnect()
          socket.connect()
          connections[1].open()
        })
        const reconnectSpy = jest.spyOn(socket.reconnectTimer, "scheduleTimeout")

        connections[0].finishClose(code)

        expect(socket.closeWasClean).toBe(false)
        expect(socket.isConnected()).toBe(true)
        expect(reconnectSpy).not.toHaveBeenCalled()
        channel.joinPush.trigger("ok", {})
        const heartbeatSpy = jest.spyOn(socket, "sendHeartbeat")
        jest.advanceTimersByTime(socket.heartbeatIntervalMs)
        expect(heartbeatSpy).toHaveBeenCalledTimes(1)

        connections[1].finishClose(1006)
        jest.advanceTimersByTime(10)

        expect(connections.length).toBe(3)
      })

      it("does not connect twice when asked to while a reconnect is scheduled", function (){
        connections[0].finishClose(1006)

        socket.connect()
        expect(connections.length).toBe(1)
        jest.advanceTimersByTime(10)

        expect(connections.length).toBe(2)
        expect(socket.conn).toBe(connections[1])
      })
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
      expect(triggerSpy).toHaveBeenCalledWith("phx_error", {
        source: "transport",
        reason: "connection_error"
      })
    })

    it("triggers channel error if joining with no connection", function (){
      const channel = socket.channel("topic")
      const triggerSpy = jest.spyOn(channel, "trigger")
      channel.join()
      expect(channel.state).toBe("joining")
      socket.onConnError("error")
      expect(triggerSpy).toHaveBeenCalledWith("phx_error", {
        source: "transport",
        reason: "connection_error"
      })
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
      expect(triggerSpy).toHaveBeenCalledWith("phx_error", {
        source: "transport",
        reason: "connection_error"
      })
    })

    it("does not trigger channel error after leave", function (){
      const channel = socket.channel("topic")
      const triggerSpy = jest.spyOn(channel, "trigger")
      channel.join().trigger("ok", {})
      channel.leave()
      expect(channel.state).toBe("closed")
      socket.onConnError("error")
      expect(triggerSpy.mock.calls.some(([event]) => event === "phx_error")).toBe(false)
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
      expect(triggerSpy.mock.calls.some(([event]) => event === "phx_error")).toBe(false)
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

    it("triggers all channels when one is removed while dispatching", function (){
      const message = {"topic": "topic", "event": "event", "payload": "payload"}
      const first = socket.channel("topic")
      const second = socket.channel("topic")
      first.on("event", () => socket.remove(first))
      const spy = jest.fn()
      second.on("event", spy)

      socket.onConnMessage({data: encode(message)})

      expect(spy).toHaveBeenCalledTimes(1)
    })

    it("triggers all onMessage callbacks when one is removed while dispatching", function (){
      const message = {"topic": "topic", "event": "event", "payload": "payload"}
      const ref = socket.onMessage(() => socket.off([ref]))
      const spy = jest.fn()
      socket.onMessage(spy)

      socket.onConnMessage({data: encode(message)})

      expect(spy).toHaveBeenCalledTimes(1)
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
    describe("when codecs finish asynchronously", function (){
      let encodings, decodings

      beforeEach(function (){
        connections = []
        encodings = []
        decodings = []
        jest.useFakeTimers()
        socket = new Socket("/socket", {
          transport: StubWebSocket,
          encode: (data, callback) => encodings.push(() => socket.defaultEncoder(data, callback)),
          decode: (data, callback) => decodings.push(() => socket.defaultDecoder(data, callback))
        })
        socket.connect()
        connections[0].open()
      })

      afterEach(function (){
        jest.useRealTimers()
      })

      it("delivers encoded pushes and decoded replies on the current connection", function (){
        const channel = socket.channel("topic")
        channel.join()
        encodings[0]()
        expect(sentJoins(connections[0]).length).toBe(1)
        connections[0].onmessage({data: encode({
          topic: "topic", event: "phx_reply", payload: {status: "ok", response: {}},
          ref: channel.joinRef(), join_ref: channel.joinRef()
        })})
        decodings[0]()
        expect(channel.state).toBe("joined")
      })

      it("does not send an old join on the replacement connection", function (){
        const channel = socket.channel("topic")
        channel.join()
        socket.disconnect()
        socket.connect()
        connections[1].open()

        encodings[0]()
        expect(connections[1].sent).toEqual([])
        encodings[1]()
        expect(sentJoins(connections[1]).map(([ref]) => ref)).toEqual([channel.joinRef()])
        expect(socket.conn).toBe(connections[1])
        expect(socket.connection.carried(channel)).toBe(true)
      })

      it("does not send an encoded push once its connection was replaced", function (){
        // the old connection is still open while its buffer drains
        connections[0].bufferedAmount = 1
        socket.push({topic: "phoenix", event: "heartbeat", payload: {}, ref: "1"})
        socket.disconnect()
        socket.connect()
        connections[1].open()

        encodings[0]()

        expect(connections[0].sent).toEqual([])
        expect(connections[1].sent).toEqual([])
      })

      it.each(["before", "during"])("sends a push started %s disconnect while the connection drains", function (when){
        const channel = socket.channel("topic")
        channel.join()
        encodings[0]()
        channel.joinPush.trigger("ok", {})
        connections[0].bufferedAmount = 1
        const received = jest.fn()
        if(when === "before"){ channel.push("event", {}).receive("ok", received) }

        socket.disconnect()
        if(when === "during"){ channel.push("event", {}).receive("ok", received) }
        encodings[1]()

        expect(connections[0].readyState).toBe(SOCKET_STATES.open)
        expect(connections[0].sent.map(([, , , event]) => event)).toEqual(["phx_join", "event"])
        const [joinRef, ref] = connections[0].sent[1]
        connections[0].onmessage({data: encode({
          topic: "topic", event: "phx_reply", payload: {status: "ok", response: {}},
          ref, join_ref: joinRef
        })})
        decodings[0]()
        expect(received).toHaveBeenCalledTimes(1)
      })

      it("does not send an encoded push once its current connection starts closing", function (){
        socket.push({topic: "topic", event: "event", payload: {}})
        socket.disconnect()

        expect(socket.conn).toBe(connections[0])
        expect(connections[0].readyState).toBe(SOCKET_STATES.closing)
        encodings[0]()
        expect(connections[0].sent).toEqual([])
      })

      it("rejoins a pending encode after the old connection finishes draining", function (){
        const channel = socket.channel("topic")
        channel.join()
        connections[0].bufferedAmount = 1
        socket.disconnect()
        socket.connect()
        connections[1].open()
        encodings[0]()
        expect(connections[1].sent).toEqual([])

        connections[0].bufferedAmount = 0
        jest.advanceTimersByTime(150)
        expect(channel.state).toBe("errored")
        jest.advanceTimersByTime(socket.rejoinAfterMs(1))
        encodings[1]()

        expect(channel.state).toBe("joining")
        expect(sentJoins(connections[1]).map(([ref]) => ref)).toEqual([channel.joinRef()])
      })

      it("drops a join superseded while encoding on the same connection", function (){
        const channel = socket.channel("topic")
        channel.join()
        channel.trigger("phx_error", {})
        channel.rejoin()

        encodings[0]()
        encodings[1]()

        expect(sentJoins(connections[0]).map(([ref]) => ref)).toEqual([channel.joinRef()])
      })

      it("sends a leave after a joining channel was removed locally", function (){
        const channel = socket.channel("topic")
        channel.join()
        encodings[0]()
        channel.leave()
        expect(socket.channels).not.toContain(channel)

        encodings[1]()

        expect(connections[0].sent.map(([, , , event]) => event)).toEqual(["phx_join", "phx_leave"])
      })

      it("does not deliver an old broadcast after the connection was replaced", function (){
        const callback = jest.fn()
        const onMessage = jest.fn()
        socket.channel("topic").on("event", callback)
        socket.onMessage(onMessage)
        connections[0].onmessage({data: encode({topic: "topic", event: "event", payload: {}})})
        socket.disconnect()
        socket.connect()
        connections[1].open()

        decodings[0]()

        expect(callback).not.toHaveBeenCalled()
        expect(onMessage).not.toHaveBeenCalled()
      })

      it("delivers a decoded message after disconnect while the buffer drains", function (){
        const callback = jest.fn()
        socket.onMessage(callback)
        connections[0].onmessage({data: encode({topic: "topic", event: "event", payload: {}})})
        connections[0].bufferedAmount = 1
        socket.disconnect()

        decodings[0]()

        expect(socket.conn).toBe(connections[0])
        expect(callback).toHaveBeenCalledWith(expect.objectContaining({topic: "topic", event: "event", payload: {}}))
      })

      it("does not deliver a message decoded after the server closed the connection", function (){
        const callback = jest.fn()
        const onMessage = jest.fn()
        socket.channel("topic").on("event", callback)
        socket.onMessage(onMessage)
        connections[0].onmessage({data: encode({topic: "topic", event: "event", payload: {}})})
        connections[0].finishClose(1000)

        decodings[0]()

        expect(callback).not.toHaveBeenCalled()
        expect(onMessage).not.toHaveBeenCalled()
      })

      it("does not reconnect when a heartbeat reply is decoded after the server closed the connection", function (){
        jest.advanceTimersByTime(socket.heartbeatIntervalMs)
        encodings[0]()
        const [[, heartbeatRef]] = connections[0].sent
        const reply = {ref: heartbeatRef, topic: "phoenix", event: "phx_reply", payload: {status: "ok", response: {}}}
        connections[0].onmessage({data: encode(reply)})
        connections[0].finishClose(1000)

        decodings[0]()
        jest.advanceTimersByTime(3 * socket.heartbeatIntervalMs)

        expect(connections.length).toBe(1)
        expect(socket.closeWasClean).toBe(true)
      })
    })

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
