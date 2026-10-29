import {jest} from "@jest/globals"
import {ResumableWebSocket, Socket} from "../js/phoenix"
import {SOCKET_STATES} from "../js/phoenix/constants"

const control = (event, payload) => JSON.stringify([null, null, "phoenix", event, payload])

class FakeWebSocket {
  constructor(url, protocols){
    this.url = url
    this.protocols = protocols
    this.readyState = SOCKET_STATES.connecting
    this.sent = []
    this.closed = null
    FakeWebSocket.instances.push(this)
  }

  get params(){ return Object.fromEntries(new URL(this.url).searchParams) }

  send(data){ this.sent.push(data) }

  close(code, reason){
    this.closed = {code, reason}
    this.readyState = SOCKET_STATES.closed
  }

  // the server side
  open(){
    this.readyState = SOCKET_STATES.open
    this.onopen()
  }

  receive(data){ this.onmessage({data}) }

  drop(code = 1006){
    this.readyState = SOCKET_STATES.closed
    this.onclose({code, reason: "", wasClean: false})
  }
}

FakeWebSocket.instances = []

const last = () => FakeWebSocket.instances.at(-1)

describe("ResumableWebSocket", () => {
  let transport, events

  const connect = ({session = true} = {}) => {
    transport = new ResumableWebSocket("ws://localhost/socket/websocket?vsn=2.0.0", ["phoenix"])
    events = []
    transport.onopen = () => events.push("open")
    transport.onmessage = ({data}) => events.push(data)
    transport.onerror = () => events.push("error")
    transport.onclose = event => events.push({close: event.code})
    transport.onsuspend = () => events.push("suspend")
    transport.onresume = () => events.push("resume")
    last().open()
    if(session){ last().receive(control("phx_session", {token: "token"})) }
  }

  // drops the WebSocket and resumes the session over a new one
  const resume = (seq, {delay = 100} = {}) => {
    last().drop()
    jest.advanceTimersByTime(delay)
    last().open()
    last().receive(control("phx_resumed", {seq}))
  }

  beforeEach(() => {
    jest.useFakeTimers()
    FakeWebSocket.instances = []
    ResumableWebSocket.WebSocket = FakeWebSocket
  })

  afterEach(() => {
    transport.close()
    ResumableWebSocket.WebSocket = null
    jest.useRealTimers()
  })

  it("asks the server for a session", () => {
    connect()
    expect(last().params).toEqual({vsn: "2.0.0", resumable: "1"})
    expect(last().protocols).toEqual(["phoenix"])
    expect(transport.readyState).toBe(SOCKET_STATES.open)
    expect(transport.token).toBe("token")
    expect(events).toEqual(["open"])
  })

  it("delivers messages and acknowledges them", () => {
    connect()
    last().receive("a")
    last().receive("b")
    expect(events).toEqual(["open", "a", "b"])
    expect(last().sent).toEqual([])

    jest.advanceTimersByTime(1000)
    expect(last().sent).toEqual([control("phx_ack", {ack: 2})])
  })

  it("resumes the session over a new WebSocket", () => {
    connect()
    last().receive("a")
    last().drop()
    expect(transport.readyState).toBe(SOCKET_STATES.open)

    jest.advanceTimersByTime(99)
    expect(FakeWebSocket.instances).toHaveLength(1)
    jest.advanceTimersByTime(1)
    expect(last().params).toEqual({vsn: "2.0.0", resumable: "1", resume: "1"})

    last().open()
    expect(last().sent).toEqual([control("phx_resume", {token: "token", ack: 1})])
    last().receive(control("phx_resumed", {seq: 0}))
    last().receive("b")
    expect(events).toEqual(["open", "a", "b"])
  })

  it("sends the messages the server did not receive again", () => {
    connect()
    transport.send("a")
    transport.send("b")
    last().receive(control("phx_ack", {seq: 1}))
    expect(transport.unconfirmed).toEqual(["b"])
    last().drop()

    // we keep the messages we send while there is no WebSocket
    transport.send("c")
    jest.advanceTimersByTime(100)
    last().open()
    last().receive(control("phx_resumed", {seq: 1}))
    expect(last().sent.slice(1)).toEqual(["b", "c"])

    // the server received "b" before the WebSocket failed
    resume(2)
    expect(last().sent.slice(1)).toEqual(["c"])
  })

  it("reports suspension once resuming failed, and resumption once it succeeded", () => {
    connect()
    last().drop()
    jest.advanceTimersByTime(100)
    expect(events).toEqual(["open"])

    last().drop()
    expect(events).toEqual(["open", "suspend"])
    jest.advanceTimersByTime(500)
    last().open()
    last().receive(control("phx_resumed", {seq: 0}))
    expect(events).toEqual(["open", "suspend", "resume"])
  })

  it("backs off while resuming keeps failing", () => {
    connect()
    const delays = []
    for(let i = 0; i < 6; i++){
      const count = FakeWebSocket.instances.length
      last().drop()
      let waited = 0
      while(FakeWebSocket.instances.length === count){
        jest.advanceTimersByTime(100)
        waited += 100
      }
      delays.push(waited)
    }
    expect(delays).toEqual([100, 500, 1000, 2000, 5000, 5000])
  })

  it("retries when the server does not answer the resume", () => {
    connect()
    transport.timeout = 1000
    last().drop()
    jest.advanceTimersByTime(100)
    const ws = last()
    ws.open()
    jest.advanceTimersByTime(1000)
    expect(ws.closed).not.toBeNull()
    jest.advanceTimersByTime(500)
    expect(last()).not.toBe(ws)
    expect(last().params.resume).toBe("1")
  })

  it("closes with the code of the session when it stopped", () => {
    connect()
    last().receive(control("phx_gone", {code: 1001}))
    expect(events).toEqual(["open", {close: 1001}])
    expect(transport.readyState).toBe(SOCKET_STATES.closed)
  })

  it.each([
    ["the session is gone", ws => ws.receive(control("phx_gone", {}))],
    ["an older server replies to the resume", ws => ws.receive(control("phx_reply", {status: "error", response: {}}))],
    ["the server treats the resume as a new connection", ws => ws.receive("a")]
  ])("closes so the socket connects again when %s", (_, receive) => {
    connect()
    last().drop()
    jest.advanceTimersByTime(100)
    const ws = last()
    ws.open()
    receive(ws)
    expect(events).toEqual(["open", {close: 3410}])
    expect(ws.closed).not.toBeNull()
    jest.advanceTimersByTime(10_000)
    expect(last()).toBe(ws)
  })

  it("closes when the server claims messages we did not send", () => {
    connect()
    transport.send("a")
    last().drop()
    jest.advanceTimersByTime(100)
    last().open()
    last().receive(control("phx_resumed", {seq: 2}))
    expect(events).toEqual(["open", {close: 3410}])
  })

  it("tells the server when it closes", () => {
    connect()
    const ws = last()
    transport.close(1000, "bye")
    expect(ws.sent).toEqual([control("phx_close", {})])
    expect(ws.closed).toEqual({code: 1000, reason: "bye"})
    expect(events).toEqual(["open", {close: 1000}])
  })

  it("does not resume after it was closed", () => {
    connect()
    last().drop()
    transport.close()
    jest.advanceTimersByTime(10_000)
    expect(FakeWebSocket.instances).toHaveLength(1)
  })

  it("does not retry when a suspension callback closes it", () => {
    connect()
    transport.onsuspend = () => transport.close()
    last().drop()
    jest.advanceTimersByTime(100)
    last().drop()
    jest.advanceTimersByTime(10_000)
    expect(FakeWebSocket.instances).toHaveLength(2)
  })

  describe("with a server that does not keep sessions", () => {
    it("behaves like a WebSocket", () => {
      connect({session: false})
      transport.send("a")
      last().receive("b")
      expect(transport.unconfirmed).toEqual([])
      expect(last().sent).toEqual(["a"])

      jest.advanceTimersByTime(1000)
      expect(last().sent).toEqual(["a"])

      last().drop(1006)
      expect(events).toEqual(["open", "b", {close: 1006}])
      jest.advanceTimersByTime(10_000)
      expect(FakeWebSocket.instances).toHaveLength(1)
    })

    it("reports errors of the WebSocket", () => {
      connect({session: false})
      last().onerror("boom")
      expect(events).toEqual(["open", "error"])
    })
  })
})

describe("Socket with resumable: true", () => {
  let socket

  beforeEach(() => {
    jest.useFakeTimers()
    FakeWebSocket.instances = []
    ResumableWebSocket.WebSocket = FakeWebSocket
  })

  afterEach(() => {
    socket.disconnect()
    ResumableWebSocket.WebSocket = null
    jest.useRealTimers()
  })

  it("resumes the session when the heartbeat times out", () => {
    socket = new Socket("ws://localhost/socket", {resumable: true, heartbeatIntervalMs: 1000})
    expect(socket.transportName(socket.transport)).toBe("ResumableWebSocket")
    socket.connect()
    last().open()
    last().receive(control("phx_session", {token: "token"}))
    const channel = socket.channel("room")
    const errors = []
    channel.onError(() => errors.push("error"))
    channel.join()

    // the heartbeat is sent, but its reply never arrives
    jest.advanceTimersByTime(1000)
    const ws = last()
    jest.advanceTimersByTime(1000)
    expect(ws.closed).not.toBeNull()
    expect(errors).toEqual([])

    jest.advanceTimersByTime(100)
    expect(last()).not.toBe(ws)
    expect(last().params.resume).toBe("1")
    expect(socket.conn).toBeInstanceOf(ResumableWebSocket)
  })
})
