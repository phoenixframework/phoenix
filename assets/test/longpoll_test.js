import {jest} from "@jest/globals"
import {LongPoll} from "../js/phoenix"
import {Socket} from "../js/phoenix"
import {AUTH_TOKEN_PREFIX, SOCKET_STATES} from "../js/phoenix/constants"
import Ajax from "../js/phoenix/ajax"

describe("LongPoll", () => {
  let originalXHR

  beforeEach(() => {
    originalXHR = global.XMLHttpRequest
    
    // Mock XMLHttpRequest
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
      responseText: JSON.stringify({status: 200, token: "token123", messages: []}),
      onreadystatechange: null,
    }))

    // Spy on Ajax.request
    jest.spyOn(Ajax, "request").mockImplementation(() => {
      return {abort: jest.fn()}
    })
  })

  afterEach(() => {
    global.XMLHttpRequest = originalXHR
    jest.restoreAllMocks()
  })

  describe("constructor", () => {
    it("should handle undefined protocols", () => {
      const longpoll = new LongPoll("http://localhost/socket/longpoll", undefined)
      
      // Verify longpoll was initialized correctly without error
      expect(longpoll.pollEndpoint).toBe("http://localhost/socket/longpoll")
      expect(longpoll.authToken).toBeUndefined()
      expect(longpoll.readyState).toBe(0) // connecting
    })

    it("should handle null protocols", () => {
      const longpoll = new LongPoll("http://localhost/socket/longpoll", null)
      
      // Verify longpoll was initialized correctly without error
      expect(longpoll.pollEndpoint).toBe("http://localhost/socket/longpoll")
      expect(longpoll.authToken).toBeUndefined()
      expect(longpoll.readyState).toBe(0) // connecting
    })

    it("should handle empty array protocols", () => {
      const longpoll = new LongPoll("http://localhost/socket/longpoll", [])
      
      // Verify longpoll was initialized correctly without error
      expect(longpoll.pollEndpoint).toBe("http://localhost/socket/longpoll")
      expect(longpoll.authToken).toBeUndefined()
      expect(longpoll.readyState).toBe(0) // connecting
    })

    it("should extract authToken when valid protocols are provided", () => {
      const authToken = "my-auth-token"
      const encodedToken = btoa(authToken)
      const protocols = ["phoenix", `${AUTH_TOKEN_PREFIX}${encodedToken}`]
      
      const longpoll = new LongPoll("http://localhost/socket/longpoll", protocols)
      
      // Verify auth token was extracted correctly
      expect(longpoll.authToken).toBe(authToken)
    })

    it("does not poll when closed before polling started", () => {
      jest.useFakeTimers()
      try {
        const longpoll = new LongPoll("http://localhost/socket/longpoll", undefined)
        longpoll.close()
        jest.runOnlyPendingTimers()

        expect(Ajax.request).not.toHaveBeenCalled()
      } finally {
        jest.useRealTimers()
      }
    })

    it("emits a close without a status code when closed without one", () => {
      const longpoll = new LongPoll("http://localhost/socket/longpoll", undefined)
      let event
      longpoll.onclose = e => { event = e }

      longpoll.close()

      expect(event.code).toBe(1005)
      expect(event.wasClean).toBe(true)
    })

    it("emits the given close code and clean flag", () => {
      const longpoll = new LongPoll("http://localhost/socket/longpoll", undefined)
      let event
      longpoll.onclose = e => { event = e }

      longpoll.close(1008, "forbidden", false)

      expect(event.code).toBe(1008)
      expect(event.reason).toBe("forbidden")
      expect(event.wasClean).toBe(false)
    })
  })

  describe("poll", () => {
    it("does not start another request when an onOpen callback disconnects", () => {
      jest.useFakeTimers()
      try {
        const socket = new Socket("/socket", {transport: LongPoll})
        socket.onOpen(() => socket.disconnect())
        socket.connect()
        const longpoll = socket.conn
        jest.advanceTimersByTime(0)
        const response = Ajax.request.mock.calls[0][6]

        response({status: 410, token: "token", messages: []})

        expect(socket.conn).toBeNull()
        expect(longpoll.readyState).toBe(SOCKET_STATES.closed)
        expect(Ajax.request).toHaveBeenCalledTimes(1)
      } finally {
        jest.useRealTimers()
      }
    })

    it("should include auth token in headers when present", () => {
      const authToken = "my-auth-token"
      const encodedToken = btoa(authToken)
      const protocols = ["phoenix", `${AUTH_TOKEN_PREFIX}${encodedToken}`]

      const longpoll = new LongPoll("http://localhost/socket/longpoll", protocols)
      longpoll.timeout = 1000
      longpoll.poll()

      // Verify Ajax.request was called with the correct headers
      expect(Ajax.request).toHaveBeenCalledWith(
        "GET",
        expect.any(String),
        {"Accept": "application/json", "X-Phoenix-AuthToken": authToken},
        null,
        expect.any(Number),
        expect.any(Function),
        expect.any(Function)
      )
    })

    it("should not include auth token in headers when not present", () => {
      const longpoll = new LongPoll("http://localhost/socket/longpoll", undefined)
      longpoll.timeout = 1000
      longpoll.poll()

      // Verify Ajax.request was called without auth token header
      expect(Ajax.request).toHaveBeenCalledWith(
        "GET",
        expect.any(String),
        {"Accept": "application/json"},
        null,
        expect.any(Number),
        expect.any(Function),
        expect.any(Function)
      )
    })

    it("should send the session token in a header", () => {
      const longpoll = new LongPoll("http://localhost/socket/longpoll", undefined)
      longpoll.timeout = 1000

      Ajax.request.mockImplementationOnce((method, url, headers, body, timeout, ontimeout, callback) => {
        callback({status: 410, token: "token123", messages: []})
        return {abort: jest.fn()}
      })

      longpoll.poll()

      expect(Ajax.request).toHaveBeenLastCalledWith(
        "GET",
        "http://localhost/socket/longpoll",
        {"Accept": "application/json", "X-Phoenix-Longpoll-Token": "token123"},
        null,
        expect.any(Number),
        expect.any(Function),
        expect.any(Function)
      )
    })

    it("should send the token header on batched pushes", () => {
      const longpoll = new LongPoll("http://localhost/socket/longpoll", undefined)
      longpoll.timeout = 1000
      longpoll.token = "token123"

      longpoll.batchSend(["msg1"])

      expect(Ajax.request).toHaveBeenLastCalledWith(
        "POST",
        "http://localhost/socket/longpoll",
        {"Content-Type": "application/x-ndjson", "X-Phoenix-Longpoll-Token": "token123"},
        "msg1",
        expect.any(Number),
        expect.any(Function),
        expect.any(Function)
      )
    })

    it("should treat 410 as error when token already exists", () => {
      const longpoll = new LongPoll("http://localhost/socket/longpoll", undefined)
      longpoll.timeout = 1000
      longpoll.token = "existing-token"

      const mockCloseAndRetry = jest.fn()
      longpoll.closeAndRetry = mockCloseAndRetry

      Ajax.request.mockImplementation((method, url, headers, body, timeout, ontimeout, callback) => {
        callback({status: 410, token: "new-token", messages: []})
        return {abort: jest.fn()}
      })

      longpoll.poll()

      expect(mockCloseAndRetry).toHaveBeenCalledWith(410, 3410, "session_gone", false)
    })
  })

  describe("queued messages", () => {
    let longpoll, events

    beforeEach(() => {
      jest.useFakeTimers()
      longpoll = new LongPoll("http://localhost/socket/longpoll")
      events = []
      longpoll.onmessage = ({data}) => events.push(data)
      longpoll.onerror = () => events.push("error")
      longpoll.onclose = () => events.push("close")
      jest.advanceTimersByTime(0)
      // the first poll opens the transport and polls again
      Ajax.request.mock.calls[0][6]({status: 410, token: "token", messages: []})
    })

    afterEach(() => jest.useRealTimers())

    it("delivers each message in its own task", () => {
      Ajax.request.mock.calls[1][6]({status: 200, token: "token", messages: ["first", "second"]})
      expect(events).toEqual([])

      jest.advanceTimersByTime(0)

      expect(events).toEqual(["first", "second"])
    })

    it("does not deliver messages after a POST timeout closed the transport", () => {
      longpoll.send("push")
      jest.advanceTimersByTime(0)
      const post = Ajax.request.mock.calls.find(([method]) => method === "POST")

      Ajax.request.mock.calls[1][6]({status: 200, token: "token", messages: ["message"]})
      post[5]()
      jest.advanceTimersByTime(0)

      expect(events).toEqual(["error", "close"])
    })

    it("does not deliver the remaining messages after a message handler closed the transport", () => {
      longpoll.onmessage = ({data}) => {
        events.push(data)
        longpoll.close()
      }

      Ajax.request.mock.calls[1][6]({status: 200, token: "token", messages: ["first", "second"]})
      jest.advanceTimersByTime(0)

      expect(events).toEqual(["first", "close"])
    })
  })

  describe("when it fails after opening", () => {
    let longpoll, events

    beforeEach(() => {
      jest.useFakeTimers()
      longpoll = new LongPoll("http://localhost/socket/longpoll")
      events = []
      longpoll.onerror = () => events.push(["error", longpoll.readyState])
      longpoll.onclose = () => events.push(["close", longpoll.readyState])
      jest.advanceTimersByTime(0)
      // the first poll opens the transport and polls again
      Ajax.request.mock.calls[0][6]({status: 410, token: "token", messages: []})
    })

    afterEach(() => jest.useRealTimers())

    const failBatch = () => {
      longpoll.send("push")
      jest.advanceTimersByTime(0)
      Ajax.request.mock.calls.find(([method]) => method === "POST")[6]({status: 500})
    }

    it.each([
      ["a poll fails", () => Ajax.request.mock.calls[1][6]({status: 500})],
      ["a poll gets no response", () => Ajax.request.mock.calls[1][6](null)],
      ["a poll times out", () => Ajax.request.mock.calls[1][5]()],
      ["the session is gone", () => Ajax.request.mock.calls[1][6]({status: 410, token: "new-token", messages: []})],
      ["a batch fails", failBatch]
    ])("is no longer open when it emits the error after %s", (_, fail) => {
      fail()

      expect(events).toEqual([["error", SOCKET_STATES.connecting], ["close", SOCKET_STATES.connecting]])
    })

    it("reports an unclean close when a poll fails", () => {
      let event
      longpoll.onclose = e => { event = e }

      Ajax.request.mock.calls[1][6]({status: 500})

      expect(event.code).toBe(1011)
      expect(event.wasClean).toBe(false)
    })
  })

  describe("with a socket", () => {
    beforeEach(() => {
      jest.useFakeTimers()
      Object.defineProperty(document, "visibilityState", {value: "visible", writable: true})
    })

    afterEach(() => jest.useRealTimers())

    it("errors channels once the socket is no longer connected", () => {
      const socket = new Socket("/socket", {transport: LongPoll})
      socket.connect()
      jest.advanceTimersByTime(0)
      Ajax.request.mock.calls[0][6]({status: 410, token: "token", messages: []})
      const channel = socket.channel("topic")
      channel.join().trigger("ok", {})
      const connectedOnError = []
      let other
      channel.onError(() => {
        connectedOnError.push(socket.isConnected())
        other = socket.channel("other")
        other.join()
      })

      Ajax.request.mock.calls[1][6]({status: 500})

      expect(connectedOnError).toEqual([false])
      // the close that follows the error does not error the channel joined by the error callback
      expect(other.state).toBe("joining")
    })

    it("does not tear down the connection created when the page is shown again", () => {
      const socket = new Socket("/socket", {transport: LongPoll})
      socket.connect()
      jest.advanceTimersByTime(0)

      // the first poll is still pending when the page is shown
      socket.handleVisibilityChange()
      const longpoll = socket.conn
      jest.advanceTimersByTime(5000)

      expect(socket.conn).toBe(longpoll)
    })
  })

  describe("request cancellation", () => {
    beforeEach(() => jest.useFakeTimers())
    afterEach(() => jest.useRealTimers())

    it("ignores response callbacks invoked synchronously by abort", () => {
      Ajax.request.mockImplementation((method, url, headers, body, timeout, ontimeout, callback) => ({
        abort: jest.fn(() => callback(null))
      }))
      const longpoll = new LongPoll("http://localhost/socket/longpoll")
      const onerror = jest.fn()
      const onclose = jest.fn()
      longpoll.onerror = onerror
      longpoll.onclose = onclose
      jest.advanceTimersByTime(0)

      longpoll.close()

      expect(onerror).not.toHaveBeenCalled()
      expect(onclose).toHaveBeenCalledTimes(1)
      expect(longpoll.readyState).toBe(SOCKET_STATES.closed)
    })

    it("ignores cancelled requests after a retry makes the transport active again", () => {
      const longpoll = new LongPoll("http://localhost/socket/longpoll")
      jest.advanceTimersByTime(0)
      const timeout = Ajax.request.mock.calls[0][5]
      const response = Ajax.request.mock.calls[0][6]
      longpoll.closeAndRetry(500, 1011, "retry", false)
      const onerror = jest.fn()
      longpoll.onerror = onerror
      longpoll.poll()

      timeout()
      response({status: 410, token: "old-token", messages: []})

      expect(onerror).not.toHaveBeenCalled()
      expect(longpoll.readyState).toBe(SOCKET_STATES.connecting)
      expect(longpoll.token).toBeNull()
      expect(Ajax.request).toHaveBeenCalledTimes(2)
      expect(longpoll.reqs.size).toBe(1)
      Ajax.request.mock.calls[1][6]({status: 410, token: "new-token", messages: []})
      expect(longpoll.readyState).toBe(SOCKET_STATES.open)
      expect(longpoll.token).toBe("new-token")
    })

    it("does not retry when an error callback disconnects", () => {
      const socket = new Socket("/socket", {transport: LongPoll})
      socket.onError(() => socket.disconnect())
      socket.connect()
      const longpoll = socket.conn
      jest.advanceTimersByTime(0)

      Ajax.request.mock.calls[0][5]()

      expect(socket.conn).toBeNull()
      expect(longpoll.readyState).toBe(SOCKET_STATES.closed)
    })

    it("does not retry when a close callback disconnects", () => {
      const socket = new Socket("/socket", {transport: LongPoll})
      socket.onClose(() => socket.disconnect())
      socket.connect()
      const longpoll = socket.conn
      jest.advanceTimersByTime(0)

      Ajax.request.mock.calls[0][5]()

      expect(socket.conn).toBeNull()
      expect(longpoll.readyState).toBe(SOCKET_STATES.closed)
    })

    it("keeps LongPoll closed when disconnect aborts a fetch request", async () => {
      Ajax.request.mockRestore()
      const originalFetch = global.fetch
      global.XMLHttpRequest = undefined
      global.fetch = jest.fn((url, {signal}) => new Promise((resolve, reject) => {
        signal.addEventListener("abort", () => {
          const error = new Error("aborted")
          error.name = "AbortError"
          reject(error)
        })
      }))
      try {
        const socket = new Socket("/socket", {transport: LongPoll})
        socket.connect()
        const longpoll = socket.conn
        jest.advanceTimersByTime(0)

        socket.disconnect()
        // drain the fetch response/error promise chain
        for(let i = 0; i < 10; i++){ await Promise.resolve() }

        expect(socket.conn).toBeNull()
        expect(longpoll.readyState).toBe(SOCKET_STATES.closed)
        expect(longpoll.reqs.size).toBe(0)
        expect(global.fetch).toHaveBeenCalledTimes(1)
      } finally {
        global.fetch = originalFetch
      }
    })

    it("should report unknown statuses through onerror and close", () => {
      const longpoll = new LongPoll("http://localhost/socket/longpoll", undefined)
      longpoll.timeout = 1000

      const onerror = jest.fn()
      const onclose = jest.fn()
      longpoll.onerror = onerror
      longpoll.onclose = onclose

      Ajax.request.mockImplementation((method, url, headers, body, timeout, ontimeout, callback) => {
        callback({status: 429, token: null, messages: []})
        return {abort: jest.fn()}
      })

      longpoll.poll()

      expect(onerror).toHaveBeenCalledWith(429)
      expect(onclose).toHaveBeenCalledWith(expect.objectContaining({code: 3429, reason: "unhandled status", wasClean: false}))
    })

    it.each([
      [{message: "Too Many Requests"}],
      [{status: -2000}],
      [{status: 2000}]
    ])("should treat a JSON body without an HTTP status as a server error: %j", (resp) => {
      const longpoll = new LongPoll("http://localhost/socket/longpoll", undefined)
      longpoll.timeout = 1000

      const onerror = jest.fn()
      const close = jest.fn()
      const closeAndRetry = jest.fn()
      longpoll.onerror = onerror
      longpoll.close = close
      longpoll.closeAndRetry = closeAndRetry

      Ajax.request.mockImplementation((method, url, headers, body, timeout, ontimeout, callback) => {
        callback(resp)
        return {abort: jest.fn()}
      })

      longpoll.poll()

      expect(onerror).toHaveBeenCalledWith(500)
      expect(closeAndRetry).toHaveBeenCalledWith(1011, "internal server error", 500)
    })
  })

  describe("batchSend", () => {
    it("should send with correct content-type header format", () => {
      const longpoll = new LongPoll("http://localhost/socket/longpoll", undefined)
      longpoll.timeout = 1000
      const messages = ["message1", "message2"]
      
      longpoll.batchSend(messages)
      
      // Verify Ajax.request was called with correct headers format
      expect(Ajax.request).toHaveBeenCalledWith(
        "POST",
        expect.any(String),
        {"Content-Type": "application/x-ndjson"},
        "message1\nmessage2",
        expect.any(Number),
        expect.any(Function),
        expect.any(Function)
      )
    })

    it("coalesces rapid send() calls and buffers sends made during an in-flight batch", () => {
      jest.useFakeTimers()
      try {
        const longpoll = new LongPoll("http://localhost/socket/longpoll", undefined)
        longpoll.timeout = 1000
        // suppress the initial poll() that the constructor schedules via setTimeout(0)
        longpoll.poll = jest.fn()

        const calls = []
        Ajax.request.mockImplementation((method, url, headers, body, timeout, ontimeout, callback) => {
          calls.push({method, body, callback})
          return {abort: jest.fn()}
        })

        // Three sends in the same tick should collapse into one currentBatch
        longpoll.send("a")
        longpoll.send("b")
        longpoll.send("c")

        expect(calls).toHaveLength(0)
        expect(longpoll.currentBatch).toEqual(["a", "b", "c"])

        // Flush the setTimeout(0) — currentBatch becomes one POST
        jest.runOnlyPendingTimers()

        expect(calls).toHaveLength(1)
        expect(calls[0].method).toBe("POST")
        expect(calls[0].body).toBe("a\nb\nc")
        expect(longpoll.currentBatch).toBeNull()
        expect(longpoll.awaitingBatchAck).toBe(true)

        // Sends during in-flight ack go to batchBuffer, not a new request
        longpoll.send("d")
        longpoll.send("e")
        expect(calls).toHaveLength(1)
        expect(longpoll.batchBuffer).toEqual(["d", "e"])

        // Ack the first batch — the buffered sends should be flushed as the next POST
        calls[0].callback({status: 200})

        expect(calls).toHaveLength(2)
        expect(calls[1].body).toBe("d\ne")
        expect(longpoll.batchBuffer).toEqual([])
        expect(longpoll.awaitingBatchAck).toBe(true)

        // Ack the buffered batch — nothing left to send
        calls[1].callback({status: 200})
        expect(calls).toHaveLength(2)
        expect(longpoll.awaitingBatchAck).toBe(false)
      } finally {
        jest.useRealTimers()
      }
    })

    it("splits 150 rapid send() calls into two requests in order", () => {
      jest.useFakeTimers()
      try {
        const longpoll = new LongPoll("http://localhost/socket/longpoll", undefined)
        longpoll.timeout = 1000
        longpoll.poll = jest.fn()

        const calls = []
        Ajax.request.mockImplementation((method, url, headers, body, timeout, ontimeout, callback) => {
          calls.push({body, callback})
          return {abort: jest.fn()}
        })

        for(let i = 0; i < 150; i++){ longpoll.send(`m${i}`) }

        // Flush the setTimeout(0) so batchSend runs on the full 150-entry batch
        jest.runOnlyPendingTimers()

        expect(calls).toHaveLength(1)
        const firstLines = calls[0].body.split("\n")
        expect(firstLines).toHaveLength(100)
        expect(firstLines[0]).toBe("m0")
        expect(firstLines[99]).toBe("m99")

        // Ack the first chunk — batchSend should recurse with the remaining 50
        calls[0].callback({status: 200})

        expect(calls).toHaveLength(2)
        const secondLines = calls[1].body.split("\n")
        expect(secondLines).toHaveLength(50)
        expect(secondLines[0]).toBe("m100")
        expect(secondLines[49]).toBe("m149")

        calls[1].callback({status: 200})
        expect(calls).toHaveLength(2)
        expect(longpoll.awaitingBatchAck).toBe(false)
      } finally {
        jest.useRealTimers()
      }
    })

    it("closes and retries when a batch POST times out", () => {
      jest.useFakeTimers()
      try {
        const longpoll = new LongPoll("http://localhost/socket/longpoll", undefined)
        longpoll.timeout = 1000
        longpoll.poll = jest.fn()
        longpoll.readyState = SOCKET_STATES.open

        const onerror = jest.fn()
        const onclose = jest.fn()
        longpoll.onerror = onerror
        longpoll.onclose = onclose

        const calls = []
        Ajax.request.mockImplementation((method, url, headers, body, timeout, ontimeout, callback) => {
          calls.push({method, body, ontimeout, callback})
          return {abort: jest.fn()}
        })

        longpoll.send("a")
        jest.runOnlyPendingTimers()

        expect(calls).toHaveLength(1)
        expect(longpoll.awaitingBatchAck).toBe(true)

        // the POST times out on the caller side
        calls[0].ontimeout()

        expect(onerror).toHaveBeenCalledWith("timeout")
        expect(onclose).toHaveBeenCalled()
        expect(longpoll.readyState).toBe(SOCKET_STATES.connecting)
        expect(longpoll.awaitingBatchAck).toBe(false)

        // later sends must not be silently buffered on the dead batch
        longpoll.send("b")
        jest.runOnlyPendingTimers()

        expect(longpoll.batchBuffer).toEqual([])
        expect(calls).toHaveLength(2)
        expect(calls[1].body).toBe("b")
      } finally {
        jest.useRealTimers()
      }
    })

    it("starts a new batch for sends after a retry dropped the pending one", () => {
      jest.useFakeTimers()
      try {
        const longpoll = new LongPoll("http://localhost/socket/longpoll", undefined)
        longpoll.poll = jest.fn()
        longpoll.readyState = SOCKET_STATES.open
        // the send is batched until the next tick, but the transport retries before that
        longpoll.send("a")
        longpoll.closeAndRetry(500, 1011, "internal server error", false)

        longpoll.send("b")
        jest.runOnlyPendingTimers()

        const posts = Ajax.request.mock.calls.filter(([method]) => method === "POST")
        expect(posts.map(([, , , body]) => body)).toEqual(["b"])
      } finally {
        jest.useRealTimers()
      }
    })
  })
})

describe("Socket with LongPoll", () => {
  describe("transportConnect", () => {
    it("should initialize with undefined protocols when no auth token", () => {
      const socket = new Socket("/socket", {transport: LongPoll})
      
      // Mock the transport to capture the protocols argument
      socket.transport = jest.fn(() => ({
        onopen: jest.fn(),
        onerror: jest.fn(),
        onmessage: jest.fn(),
        onclose: jest.fn()
      }))
      
      socket.transportConnect()
      
      // Verify that the transport was called with undefined protocols
      expect(socket.transport).toHaveBeenCalledWith(
        expect.any(String),
        undefined
      )
    })
    
    it("should only set protocols array when auth token is present", () => {
      const authToken = "my-auth-token"
      const socket = new Socket("/socket", {
        transport: LongPoll,
        authToken
      })

      // Mock the transport to capture the protocols argument
      socket.transport = jest.fn(() => ({
        onopen: jest.fn(),
        onerror: jest.fn(),
        onmessage: jest.fn(),
        onclose: jest.fn()
      }))
      
      socket.transportConnect()
      
      // Verify that the transport was called with correct protocols array
      expect(socket.transport).toHaveBeenCalledWith(
        expect.any(String),
        ["phoenix", `${AUTH_TOKEN_PREFIX}${btoa(authToken).replace(/=/g, "")}`]
      )
    })
  })
})

describe("Ajax.request", () => {
  let originalXMLHttpRequest, originalFetch, originalAbortController

  beforeEach(() => {
    originalXMLHttpRequest = global.XMLHttpRequest
    originalFetch = global.fetch
    originalAbortController = global.AbortController

    // Mock AbortController
    global.AbortController = jest.fn(() => ({
      abort: jest.fn(),
      signal: {}
    }))

    // Mock XMLHttpRequest
    global.XMLHttpRequest = jest.fn(() => ({
      open: jest.fn(),
      send: jest.fn(),
      setRequestHeader: jest.fn(),
      onreadystatechange: null,
      readyState: 4,
      status: 200,
      responseText: JSON.stringify({success: true})
    }))

    // Mock fetch
    global.fetch = jest.fn(() =>
      Promise.resolve({
        text: () => Promise.resolve(JSON.stringify({success: true}))
      })
    )
  })

  afterEach(() => {
    global.XMLHttpRequest = originalXMLHttpRequest
    global.fetch = originalFetch
    global.AbortController = originalAbortController
    jest.restoreAllMocks()
  })

  it("should use XMLHttpRequest by default", () => {
    Ajax.request("GET", "/test-endpoint", {}, null, 0, null, (response) => {
      expect(response).toEqual({success: true})
    })

    expect(global.XMLHttpRequest).toHaveBeenCalled()
  })

  it("should use fetch when XMLHttpRequest is not available", () => {
    global.XMLHttpRequest = undefined // Simulate it being unavailable
    Ajax.request("GET", "/test-endpoint", {}, null, 0, null, (response) => {
      expect(response).toEqual({success: true})
    })

    expect(global.fetch).toHaveBeenCalledWith(
      "/test-endpoint",
      expect.objectContaining({
        method: "GET",
      })
    )
  })

  it("clears the timeout timer when fetch completes successfully", () => {
    global.XMLHttpRequest = undefined
    const setTimeoutSpy = jest.spyOn(global, "setTimeout")
    const clearTimeoutSpy = jest.spyOn(global, "clearTimeout")

    return new Promise((resolve, reject) => {
      Ajax.request("GET", "/test-endpoint", {}, null, 5000, null, (response) => {
        try {
          expect(response).toEqual({success: true})
          const timerId = setTimeoutSpy.mock.results[0].value
          expect(clearTimeoutSpy).toHaveBeenCalledWith(timerId)
          resolve()
        } catch(err){
          reject(err)
        }
      })
    })
  })

  it("clears the timeout timer when fetch errors", () => {
    global.XMLHttpRequest = undefined
    global.fetch = jest.fn(() => Promise.reject(new Error("Network error")))
    const setTimeoutSpy = jest.spyOn(global, "setTimeout")
    const clearTimeoutSpy = jest.spyOn(global, "clearTimeout")

    return new Promise((resolve, reject) => {
      Ajax.request("GET", "/test-endpoint", {}, null, 5000, null, (response) => {
        try {
          expect(response).toBeNull()
          const timerId = setTimeoutSpy.mock.results[0].value
          expect(clearTimeoutSpy).toHaveBeenCalledWith(timerId)
          resolve()
        } catch(err){
          reject(err)
        }
      })
    })
  })

  it("does not set or clear timeout timer when timeout is 0 or not specified", () => {
    global.XMLHttpRequest = undefined
    const setTimeoutSpy = jest.spyOn(global, "setTimeout")
    const clearTimeoutSpy = jest.spyOn(global, "clearTimeout")

    return new Promise((resolve, reject) => {
      Ajax.request("GET", "/test-endpoint", {}, null, 0, null, (response) => {
        try {
          expect(response).toEqual({success: true})
          expect(setTimeoutSpy).not.toHaveBeenCalled()
          expect(clearTimeoutSpy).not.toHaveBeenCalled()
          resolve()
        } catch(err){
          reject(err)
        }
      })
    })
  })

  it("invokes ontimeout and clears timer when fetch rejects with AbortError", () => {
    global.XMLHttpRequest = undefined
    const abortError = new Error("The user aborted a request.")
    abortError.name = "AbortError"
    global.fetch = jest.fn(() => Promise.reject(abortError))
    const setTimeoutSpy = jest.spyOn(global, "setTimeout")
    const clearTimeoutSpy = jest.spyOn(global, "clearTimeout")

    return new Promise((resolve, reject) => {
      const callback = jest.fn(() => reject(new Error("callback should not be called on AbortError")))
      const ontimeout = () => {
        try {
          expect(callback).not.toHaveBeenCalled()
          const timerId = setTimeoutSpy.mock.results[0].value
          expect(clearTimeoutSpy).toHaveBeenCalledWith(timerId)
          resolve()
        } catch(err){
          reject(err)
        }
      }

      Ajax.request("GET", "/test-endpoint", {}, null, 5000, ontimeout, callback)
    })
  })
})
