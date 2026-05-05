import {jest} from "@jest/globals"
import {LongPoll} from "../js/phoenix"
import {Socket} from "../js/phoenix"
import {AUTH_TOKEN_PREFIX} from "../js/phoenix/constants"
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
  })

  describe("poll", () => {
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

    it("should treat 410 as error when token already exists", () => {
      const longpoll = new LongPoll("http://localhost/socket/longpoll", undefined)
      longpoll.timeout = 1000
      longpoll.token = "existing-token"

      const mockOnerror = jest.fn()
      const mockCloseAndRetry = jest.fn()
      longpoll.onerror = mockOnerror
      longpoll.closeAndRetry = mockCloseAndRetry

      Ajax.request.mockImplementation((method, url, headers, body, timeout, ontimeout, callback) => {
        callback({status: 410, token: "new-token", messages: []})
        return {abort: jest.fn()}
      })

      longpoll.poll()

      expect(mockOnerror).toHaveBeenCalledWith(410)
      expect(mockCloseAndRetry).toHaveBeenCalledWith(3410, "session_gone", false)
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
        params: {token: authToken}
      })
      
      // Set auth token
      socket.authToken = authToken
      
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
})

