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

describe("LongPoll resuming", () => {
  let longpoll, events

  const requests = method => Ajax.request.mock.calls.filter(([m]) => m === method)
  const last = method => requests(method).at(-1)
  const params = call => Object.fromEntries(new URL(call[1]).searchParams)
  const respond = (call, resp) => call[6](resp)

  // the server keeps the messages until we acknowledge them when it numbers them
  const open = (resp = {status: 410, token: "token", messages: [], last: 0}) => {
    longpoll = new LongPoll("http://localhost/socket/longpoll")
    events = []
    longpoll.onopen = () => events.push("open")
    longpoll.onmessage = ({data}) => events.push(data)
    longpoll.onerror = () => events.push("error")
    longpoll.onclose = () => events.push("close")
    longpoll.onsuspend = () => events.push("suspend")
    longpoll.onresume = () => events.push("resume")
    jest.advanceTimersByTime(0)
    respond(last("GET"), resp)
  }

  beforeEach(() => {
    jest.useFakeTimers()
    jest.spyOn(Ajax, "request").mockImplementation(() => ({abort: jest.fn()}))
  })

  afterEach(() => {
    longpoll.close()
    jest.useRealTimers()
    jest.restoreAllMocks()
  })

  it("acknowledges the last message it received with the next poll", () => {
    open()
    expect(params(last("GET")).ack).toBe("0")

    respond(last("GET"), {status: 200, token: "token", messages: ["a"], last: 1})
    jest.advanceTimersByTime(0)
    expect(params(last("GET")).ack).toBe("1")

    // a poll without new messages keeps the ack
    respond(last("GET"), {status: 204, token: "token", last: 1})
    expect(params(last("GET")).ack).toBe("1")
  })

  // TODO: Remove in Phoenix 1.10, together with degrade()
  it("does not acknowledge when the server does not number its messages", () => {
    open({status: 410, token: "token", messages: []})
    expect(params(last("GET")).ack).toBeUndefined()
  })

  it.each([
    ["gets no response", call => respond(call, null)],
    ["times out", call => call[5]()]
  ])("polls again with the same ack when a poll %s", (_, fail) => {
    open()
    respond(last("GET"), {status: 200, token: "token", messages: ["a"], last: 1})
    jest.advanceTimersByTime(0)
    const polls = requests("GET").length

    fail(last("GET"))
    jest.advanceTimersByTime(99)
    expect(requests("GET")).toHaveLength(polls)
    jest.advanceTimersByTime(1)

    expect(requests("GET")).toHaveLength(polls + 1)
    expect(params(last("GET")).ack).toBe("1")
    expect(events).not.toContain("error")
    expect(events).not.toContain("close")
  })

  it("backs off while requests keep failing", () => {
    open()
    const delays = []
    for(let i = 0; i < 6; i++){
      const polls = requests("GET").length
      respond(last("GET"), null)
      let waited = 0
      while(requests("GET").length === polls){
        jest.advanceTimersByTime(100)
        waited += 100
      }
      delays.push(waited)
    }

    expect(delays).toEqual([100, 500, 1000, 2000, 5000, 5000])
  })

  it("reports suspension once a retry failed as well, and resumption once requests succeed", () => {
    open()
    respond(last("GET"), null)
    jest.advanceTimersByTime(100)
    expect(events).toEqual(["open"])

    respond(last("GET"), null)
    jest.advanceTimersByTime(500)
    respond(last("GET"), null)
    jest.advanceTimersByTime(1000)
    expect(events).toEqual(["open", "suspend"])

    respond(last("GET"), {status: 204, token: "token", last: 0})
    expect(events).toEqual(["open", "suspend", "resume"])

    // a single failure after that is not an interruption yet
    respond(last("GET"), null)
    jest.advanceTimersByTime(100)
    expect(events).toEqual(["open", "suspend", "resume"])
  })

  it("waits for both GET and POST to recover", () => {
    open()
    longpoll.send("a")
    jest.advanceTimersByTime(0)
    respond(last("GET"), null)
    respond(last("POST"), null)
    jest.advanceTimersByTime(100)
    respond(last("GET"), null)
    respond(last("POST"), null)
    jest.advanceTimersByTime(500)
    expect(events).toEqual(["open", "suspend"])

    respond(last("GET"), {status: 204, token: "token", last: 0})
    expect(events).toEqual(["open", "suspend"])
    respond(last("POST"), {status: 200, seq: 1})
    expect(events).toEqual(["open", "suspend", "resume"])
  })

  it("delivers the recovered messages before reporting resumption", () => {
    open()
    respond(last("GET"), null)
    jest.advanceTimersByTime(100)
    respond(last("GET"), null)
    jest.advanceTimersByTime(500)
    respond(last("GET"), {status: 200, token: "token", messages: ["a", "b"], last: 2})
    expect(events).toEqual(["open", "suspend"])
    jest.advanceTimersByTime(0)
    expect(events).toEqual(["open", "suspend", "a", "b", "resume"])
    expect(params(last("GET")).ack).toBe("2")
  })

  it("does not deliver already received messages again", () => {
    open()
    respond(last("GET"), {status: 200, token: "token", messages: ["a"], last: 1})
    jest.advanceTimersByTime(0)
    respond(last("GET"), {status: 200, token: "token", messages: ["a"], last: 1})
    jest.advanceTimersByTime(0)
    expect(events).toEqual(["open", "a"])

    // a late poll returns the messages after an older ack, with new ones
    respond(last("GET"), {status: 200, token: "token", messages: ["a", "b"], last: 2})
    jest.advanceTimersByTime(0)
    expect(events).toEqual(["open", "a", "b"])
    expect(params(last("GET")).ack).toBe("2")
  })

  it("closes when messages are missing before the ones it receives", () => {
    open()
    respond(last("GET"), {status: 200, token: "token", messages: ["c"], last: 3})
    jest.advanceTimersByTime(0)
    expect(events).toEqual(["open", "error", "close"])
  })

  it("resumes the session with the polls after a failed one", () => {
    open()
    expect(params(last("GET")).resume).toBeUndefined()
    respond(last("GET"), null)
    jest.advanceTimersByTime(100)
    expect(params(last("GET")).resume).toBe("1")
    respond(last("GET"), null)
    jest.advanceTimersByTime(500)
    expect(params(last("GET")).resume).toBe("1")

    respond(last("GET"), {status: 204, token: "token", last: 0})
    expect(params(last("GET")).resume).toBeUndefined()
  })

  // TODO: Remove in Phoenix 1.10, together with degrade()
  it("does not resume the session when the server does not number its messages", () => {
    open({status: 410, token: "token", messages: []})
    expect(params(last("GET")).resume).toBeUndefined()
  })

  it("does not retry when a suspension callback closes the transport", () => {
    open()
    longpoll.onsuspend = () => longpoll.close()
    respond(last("GET"), null)
    jest.advanceTimersByTime(100)
    respond(last("GET"), null)
    const polls = requests("GET").length
    jest.advanceTimersByTime(10_000)
    expect(requests("GET")).toHaveLength(polls)
    expect(longpoll.retryTimers.size).toBe(0)
  })

  it.each([403, 500])("does not report resumption before failing with status %s", status => {
    open()
    respond(last("GET"), null)
    jest.advanceTimersByTime(100)
    respond(last("GET"), null)
    jest.advanceTimersByTime(500)
    respond(last("GET"), {status, token: "token"})
    expect(events).toEqual(["open", "suspend", "error", "close"])
  })

  it("closes when the session is gone", () => {
    open()
    respond(last("GET"), {status: 410, token: "new-token", messages: [], last: 0})

    expect(events).toEqual(["open", "error", "close"])
  })

  it("does not retry after it was closed", () => {
    open()
    respond(last("GET"), null)
    longpoll.close()
    const polls = requests("GET").length
    jest.advanceTimersByTime(10_000)

    expect(requests("GET")).toHaveLength(polls)
  })

  it("numbers the messages it sends and sends a batch again when it gets no response", () => {
    open()
    longpoll.send("a")
    longpoll.send("b")
    jest.advanceTimersByTime(0)
    expect(params(last("POST")).seq).toBe("1")
    expect(last("POST")[3]).toBe("a\nb")

    longpoll.send("c")
    respond(last("POST"), null)
    jest.advanceTimersByTime(100)
    expect(requests("POST")).toHaveLength(2)
    expect(params(last("POST")).seq).toBe("1")
    expect(last("POST")[3]).toBe("a\nb")

    respond(last("POST"), {status: 200, seq: 1})
    expect(params(last("POST")).seq).toBe("3")
    expect(last("POST")[3]).toBe("c")
  })

  // TODO: Remove in Phoenix 1.10, together with degrade()
  it("does not number the messages when the server does not number its messages", () => {
    open({status: 410, token: "token", messages: []})
    longpoll.send("a")
    jest.advanceTimersByTime(0)

    expect(params(last("POST")).seq).toBeUndefined()
  })

  it("sends messages pushed by a resume callback after a POST recovers", () => {
    open()
    longpoll.onresume = () => longpoll.send("b")
    longpoll.send("a")
    jest.advanceTimersByTime(0)
    respond(last("POST"), null)
    jest.advanceTimersByTime(100)
    respond(last("POST"), null)
    jest.advanceTimersByTime(500)
    respond(last("POST"), {status: 200, seq: 1})
    jest.advanceTimersByTime(0)
    expect(last("POST")[3]).toBe("b")
    expect(params(last("POST")).seq).toBe("2")
  })

  // During a rolling deploy, a node with an older server forwards our requests
  // without ack and seq, so the session treats us like an older client.
  //
  // TODO: Remove in Phoenix 1.10, together with degrade()
  describe("with a node of an older server", () => {
    it("delivers the messages of a poll and stops resuming", () => {
      open()
      respond(last("GET"), {status: 200, token: "token", messages: ["a"]})
      jest.advanceTimersByTime(0)
      expect(events).toEqual(["open", "a"])
      expect(params(last("GET")).ack).toBeUndefined()

      // the next failure reconnects, as the session no longer keeps messages for us
      respond(last("GET"), null)
      expect(events).toEqual(["open", "a", "error", "close"])
    })

    it.each([
      ["with messages", {status: 200, token: "token", messages: ["a"]}],
      ["without messages", {status: 204, token: "token"}]
    ])("reconnects when a retried poll %s was answered by it", (_, resp) => {
      open()
      respond(last("GET"), null)
      jest.advanceTimersByTime(100)
      // the session dropped the messages of the response we lost
      respond(last("GET"), resp)
      jest.advanceTimersByTime(0)
      expect(events).toEqual(["open", "error", "close"])
    })

    it("stops resuming after it answered a POST", () => {
      open()
      longpoll.send("a")
      jest.advanceTimersByTime(0)
      respond(last("POST"), {status: 200})
      longpoll.send("b")
      jest.advanceTimersByTime(0)
      expect(params(last("POST")).seq).toBeUndefined()

      respond(last("POST"), null)
      expect(events).toEqual(["open", "error", "close"])
    })

    it("keeps the downgrade when an outstanding modern poll completes", () => {
      open()
      longpoll.send("a")
      jest.advanceTimersByTime(0)
      respond(last("POST"), {status: 200})
      respond(last("GET"), {status: 204, token: "token", last: 0})
      expect(params(last("GET")).ack).toBeUndefined()

      longpoll.send("b")
      jest.advanceTimersByTime(0)
      expect(params(last("POST")).seq).toBeUndefined()
      respond(last("GET"), null)
      expect(events).toEqual(["open", "error", "close"])
    })

    it("fails a pending POST retry when a legacy poll downgrades the session", () => {
      open()
      longpoll.send("a")
      jest.advanceTimersByTime(0)
      respond(last("POST"), null)
      respond(last("GET"), {status: 204, token: "token"})
      jest.advanceTimersByTime(1000)

      expect(requests("POST")).toHaveLength(1)
      expect(longpoll.retryTimers.size).toBe(0)
      expect(events).toEqual(["open", "error", "close"])
    })

    it("fails a pending GET retry when a legacy POST downgrades the session", () => {
      open()
      longpoll.send("a")
      jest.advanceTimersByTime(0)
      respond(last("GET"), null)
      const polls = requests("GET").length
      respond(last("POST"), {status: 200})
      jest.advanceTimersByTime(1000)

      expect(requests("GET")).toHaveLength(polls)
      expect(longpoll.retryTimers.size).toBe(0)
      expect(events).toEqual(["open", "error", "close"])
    })

    it("keeps resuming while POSTs are answered with seq", () => {
      open()
      longpoll.send("a")
      jest.advanceTimersByTime(0)
      respond(last("POST"), {status: 200, seq: 1})
      longpoll.send("b")
      jest.advanceTimersByTime(0)
      expect(params(last("POST")).seq).toBe("2")

      respond(last("POST"), null)
      expect(events).toEqual(["open"])
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

describe("LongPoll continuing a session of another transport", () => {
  let longpoll, events

  const requests = method => Ajax.request.mock.calls.filter(([m]) => m === method)
  const last = method => requests(method).at(-1)
  const params = call => Object.fromEntries(new URL(call[1]).searchParams)
  const respond = (call, resp) => call[6](resp)

  const start = (session = {token: "token", received: 3, confirmed: 1, unconfirmed: ["b", "c"]}) => {
    longpoll = new LongPoll("ws://localhost/socket/websocket?vsn=2.0.0")
    longpoll.resumeSession(session)
    events = []
    longpoll.onopen = () => events.push("open")
    longpoll.onmessage = ({data}) => events.push(data)
    longpoll.onerror = () => events.push("error")
    longpoll.onclose = event => events.push({close: event.code})
    jest.advanceTimersByTime(0)
  }

  beforeEach(() => {
    jest.useFakeTimers()
    jest.spyOn(Ajax, "request").mockImplementation(() => ({abort: jest.fn()}))
  })

  afterEach(() => {
    longpoll.close()
    jest.useRealTimers()
    jest.restoreAllMocks()
  })

  it("resumes the session with its first poll", () => {
    start()
    const poll = last("GET")
    expect(poll[1]).toMatch(/^http:\/\/localhost\/socket\/longpoll\?/)
    expect(params(poll)).toEqual({vsn: "2.0.0", ack: "3", resume: "1"})
    expect(poll[2]["X-Phoenix-Longpoll-Token"]).toBe("token")
    expect(longpoll.readyState).toBe(SOCKET_STATES.connecting)
  })

  it("sends the messages the server did not confirm once it resumed", () => {
    start()
    longpoll.send("d")
    jest.advanceTimersByTime(0)
    expect(requests("POST")).toHaveLength(0)

    respond(last("GET"), {status: 200, token: "token", messages: ["x"], last: 4})
    expect(events).toEqual(["open"])
    jest.advanceTimersByTime(0)
    expect(events).toEqual(["open", "x"])
    expect(params(last("POST")).seq).toBe("2")
    expect(last("POST")[3]).toBe("b\nc\nd")
    expect(params(last("GET")).resume).toBeUndefined()
  })

  it("closes when the session is gone", () => {
    start()
    respond(last("GET"), {status: 410, token: "new-token", messages: [], last: 0})
    expect(events).toEqual(["error", {close: 3410}])
  })

  // TODO: Remove in Phoenix 1.10, together with degrade()
  it("closes when a node with an older server answers", () => {
    start()
    respond(last("GET"), {status: 204, token: "token"})
    expect(events).toEqual(["error", {close: 3410}])
  })

  it("delivers binary messages", () => {
    start()
    respond(last("GET"), {status: 200, token: "token", messages: ["base64:AQID"], last: 4})
    jest.advanceTimersByTime(0)
    expect(new Uint8Array(events[1])).toEqual(new Uint8Array([1, 2, 3]))
  })
})
