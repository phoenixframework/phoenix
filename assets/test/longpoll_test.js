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
