import {jest} from "@jest/globals"
import {ResumableWebSocket, Socket} from "../js/phoenix"
import {SOCKET_STATES} from "../js/phoenix/constants"
import Ajax from "../js/phoenix/ajax"

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

const OriginalWebSocket = global.WebSocket

const last =() => FakeWebSocket.instances.at(-1)

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
    last().receive(control("phx_resumed", {seq, last: transport.received}))
  }

  beforeEach(() => {
    jest.useFakeTimers()
    FakeWebSocket.instances = []
    global.WebSocket = FakeWebSocket
  })

  afterEach(() => {
    transport.close()
    global.WebSocket = OriginalWebSocket
    jest.useRealTimers()
  })

  it("asks the server for a session", () => {
    connect()
    expect(last().params).toEqual({vsn: "2.0.0", "phx:resumable": "1"})
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
    expect(last().params).toEqual({vsn: "2.0.0", "phx:resumable": "1", "phx:resume": "1"})

    last().open()
    expect(last().sent).toEqual([control("phx_resume", {token: "token", ack: 1})])
    last().receive(control("phx_resumed", {seq: 0, last: 2}))
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
    last().receive(control("phx_resumed", {seq: 1, last: 0}))
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
    last().receive(control("phx_resumed", {seq: 0, last: 0}))
    expect(events).toEqual(["open", "suspend"])
    jest.advanceTimersByTime(0)
    expect(events).toEqual(["open", "suspend", "resume"])
  })

  it("resumes after the delay from resumeAfterMs", () => {
    connect()
    const tries = []
    transport.resumeAfterMs = (attempt) => {
      tries.push(attempt)
      return 30
    }

    const ws = last()
    ws.drop()
    jest.advanceTimersByTime(29)
    expect(last()).toBe(ws)
    jest.advanceTimersByTime(1)
    expect(last()).not.toBe(ws)

    last().drop()
    expect(tries).toEqual([1, 2])
  })

  it("reads the connection info for each new WebSocket", () => {
    connect()
    transport.connectionInfo = () => ({
      endPoint: "ws://localhost/socket/websocket?vsn=2.0.0&token=new",
      protocols: ["phoenix", "new"]
    })

    last().drop()
    jest.advanceTimersByTime(100)
    expect(last().params).toEqual({vsn: "2.0.0", token: "new", "phx:resumable": "1", "phx:resume": "1"})
    expect(last().protocols).toEqual(["phoenix", "new"])
  })

  describe("replay before recovery", () => {
    beforeEach(() => {
      connect()
      last().drop()
      jest.advanceTimersByTime(100)
      last().drop()
      jest.advanceTimersByTime(500)
      last().open()
    })

    it("delivers replay and its promises before notifying recovery", async () => {
      transport.onmessage = ({data}) => {
        events.push(data)
        Promise.resolve().then(() => events.push(`settled ${data}`))
      }
      transport.onresume = () => {
        events.push("resume")
        transport.send("after recovery")
      }
      transport.send("queued")
      last().receive(control("phx_resumed", {seq: 0, last: 2}))
      expect(last().sent.slice(1)).toEqual(["queued"])

      last().receive("a")
      await jest.advanceTimersByTimeAsync(0)
      expect(events).toEqual(["open", "suspend", "a", "settled a"])

      last().receive("b")
      expect(events).not.toContain("resume")
      await jest.advanceTimersByTimeAsync(0)
      expect(events).toEqual(["open", "suspend", "a", "settled a", "b", "settled b", "resume"])
      expect(last().sent.slice(1)).toEqual(["queued", "after recovery"])

      last().receive("c")
      await jest.advanceTimersByTimeAsync(0)
      expect(events.filter(event => event === "resume")).toHaveLength(1)
    })

    it("does not notify recovery when a replay callback closes the transport", () => {
      transport.onmessage = () => transport.close()
      last().receive(control("phx_resumed", {seq: 0, last: 1}))
      last().receive("a")
      jest.advanceTimersByTime(0)
      expect(events).not.toContain("resume")
      expect(transport.readyState).toBe(SOCKET_STATES.closed)
    })

    it.each(["close", "drop"])("cancels a queued recovery notification on %s", action => {
      last().receive(control("phx_resumed", {seq: 0, last: 1}))
      last().receive("a")
      if(action === "close"){ transport.close() } else { last().drop() }
      jest.advanceTimersByTime(0)
      expect(events).not.toContain("resume")
    })

    it("waits for replay on the replacement of a connection lost during recovery", () => {
      last().receive(control("phx_resumed", {seq: 0, last: 2}))
      last().receive("a")
      last().drop()
      jest.advanceTimersByTime(100)
      last().open()
      last().receive(control("phx_resumed", {seq: 0, last: 2}))
      jest.advanceTimersByTime(0)
      expect(events).toEqual(["open", "suspend", "a"])

      last().receive("b")
      jest.advanceTimersByTime(0)
      expect(events).toEqual(["open", "suspend", "a", "b", "resume"])
    })

    it.each([undefined, -1, "0"])("rejects an invalid replay boundary %s", lastMessage => {
      last().receive(control("phx_resumed", {seq: 0, last: lastMessage}))
      expect(events).toEqual(["open", "suspend", {close: 3410}])
    })
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
    transport.resumeTimeout = 1000
    last().drop()
    jest.advanceTimersByTime(100)
    const ws = last()
    ws.open()
    jest.advanceTimersByTime(1000)
    expect(ws.closed).not.toBeNull()
    jest.advanceTimersByTime(500)
    expect(last()).not.toBe(ws)
    expect(last().params["phx:resume"]).toBe("1")
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
    last().receive(control("phx_resumed", {seq: 2, last: 0}))
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

  describe("with a long polling fallback", () => {
    const polls = () => Ajax.request.mock.calls.filter(([method]) => method === "GET")
    const posts = () => Ajax.request.mock.calls.filter(([method]) => method === "POST")
    const params = call => Object.fromEntries(new URL(call[1]).searchParams)

    beforeEach(() => {
      jest.spyOn(Ajax, "request").mockImplementation(() => ({abort: jest.fn()}))
    })

    afterEach(() => jest.restoreAllMocks())

    const interrupt = () => {
      connect()
      transport.longPollFallbackMs = 2000
      last().receive("a")
      transport.send("x")
      last().drop()
    }

    it("continues with the current connection info", () => {
      interrupt()
      transport.connectionInfo = () => ({endPoint: "ws://localhost/socket/websocket?vsn=2.0.0&token=new"})
      jest.advanceTimersByTime(2001)
      expect(params(polls()[0]).token).toBe("new")
      expect(transport.longpoll.connectionInfo).toBe(transport.connectionInfo)
    })

    it("passes resumeAfterMs to the LongPoll", () => {
      interrupt()
      const resumeAfterMs = () => 30
      transport.resumeAfterMs = resumeAfterMs
      jest.advanceTimersByTime(2000)
      expect(transport.longpoll.resumeAfterMs).toBe(resumeAfterMs)
    })

    it("continues the session with long polling when resuming takes too long", () => {
      interrupt()
      jest.advanceTimersByTime(100)
      last().drop()
      jest.advanceTimersByTime(1900)
      expect(polls()).toHaveLength(0)
      const ws = last()

      jest.advanceTimersByTime(100)
      expect(ws.closed).not.toBeNull()
      jest.advanceTimersByTime(0)
      expect(params(polls()[0])).toEqual({vsn: "2.0.0", "phx:ack": "1", "phx:resume": "1"})
      expect(polls()[0][2]["X-Phoenix-Longpoll-Token"]).toBe("token")

      // the session resumed over long polling
      polls()[0][6]({status: 200, token: "token", messages: ["b"], last: 2})
      expect(events).toEqual(["open", "a", "suspend"])
      jest.advanceTimersByTime(0)
      expect(events).toEqual(["open", "a", "suspend", "b", "resume"])
      expect(params(posts()[0])["phx:seq"]).toBe("1")
      expect(posts()[0][3]).toBe("x")

      // we keep long polling and do not open WebSockets anymore
      transport.send("y")
      jest.advanceTimersByTime(10_000)
      expect(FakeWebSocket.instances).toHaveLength(3)
    })

    it.each([
      {status: 200, messages: ["b"], last: 2},
      {status: 204, messages: [], last: 1}
    ])("keeps replay order when a resume callback pushes after a $status poll", response => {
      interrupt()
      transport.onresume = () => transport.send("z")
      jest.advanceTimersByTime(100)
      last().drop()
      jest.advanceTimersByTime(1901)
      transport.send("y")

      polls()[0][6]({...response, token: "token"})
      jest.advanceTimersByTime(0)

      expect(params(posts()[0])["phx:seq"]).toBe("1")
      // A response with messages sends the replay before the recovery callback.
      // A response without messages can still batch both in the same turn.
      posts()[0][6]({status: 200, seq: 1})
      expect(posts().map(call => call[3]).join("\n")).toBe("x\ny\nz")
      expect(posts().map(call => params(call)["phx:seq"])).toEqual(response.status === 200 ? ["1", "3"] : ["1"])
    })

    it("does not fall back while replaying a session resumed over a WebSocket", () => {
      interrupt()
      jest.advanceTimersByTime(100)
      last().open()
      last().receive(control("phx_resumed", {seq: 1, last: 2}))
      jest.advanceTimersByTime(10_000)
      expect(polls()).toHaveLength(0)
    })

    it("does not notify recovery when a fallback message callback closes it", () => {
      interrupt()
      jest.advanceTimersByTime(100)
      last().drop()
      jest.advanceTimersByTime(1901)
      transport.onmessage = () => transport.close()

      polls()[0][6]({status: 200, token: "token", messages: ["b"], last: 2})
      jest.advanceTimersByTime(0)

      expect(events).not.toContain("resume")
      expect(transport.readyState).toBe(SOCKET_STATES.closed)
    })

    it("closes when the session is gone", () => {
      interrupt()
      // the first poll runs right after we fall back
      jest.advanceTimersByTime(2001)
      polls()[0][6]({status: 410, token: "new", messages: [], last: 0})
      expect(events).toEqual(["open", "a", "error", {close: 3410}])
      expect(transport.readyState).toBe(SOCKET_STATES.closed)
    })

    it.each([403, 410, 500])("is no longer open when the fallback reports %s", status => {
      interrupt()
      jest.advanceTimersByTime(2001)
      const states = []
      transport.onerror = () => states.push(transport.readyState)
      transport.onclose = () => states.push(transport.readyState)

      polls()[0][6]({status})

      expect(states).toEqual([SOCKET_STATES.connecting, SOCKET_STATES.closed])
    })

    it("lets an error callback close and clean up the fallback", () => {
      interrupt()
      jest.advanceTimersByTime(2001)
      const longpoll = transport.longpoll
      transport.onerror = () => transport.close(1000, "done")

      polls()[0][6]({status: 410})
      jest.advanceTimersByTime(10_000)

      expect(longpoll.readyState).toBe(SOCKET_STATES.closed)
      expect(longpoll.reqs.size).toBe(0)
      expect(transport.longpoll).toBeNull()
      expect(events).toEqual(["open", "a", {close: 1000}])
      expect(polls()).toHaveLength(1)
    })

    it("closes the LongPoll when it closes", () => {
      interrupt()
      // the first poll runs right after we fall back
      jest.advanceTimersByTime(2001)
      const longpoll = transport.longpoll
      transport.close(1000, "bye")
      expect(longpoll.readyState).toBe(SOCKET_STATES.closed)
      expect(events.at(-1)).toEqual({close: 1000})
    })
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
    global.WebSocket = FakeWebSocket
  })

  afterEach(() => {
    socket.disconnect()
    global.WebSocket = OriginalWebSocket
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
    expect(last().params["phx:resume"]).toBe("1")
    expect(socket.conn).toBeInstanceOf(ResumableWebSocket)
  })

  it("does not wait for the long polling timeout when the server does not answer the resume", () => {
    socket = new Socket("ws://localhost/socket", {resumable: true, longpollerTimeout: 60_000})
    socket.connect()
    last().open()
    last().receive(control("phx_session", {token: "token"}))
    last().drop()
    jest.advanceTimersByTime(100)
    const ws = last()
    ws.open()

    // the server keeps the session for 15 seconds by default
    jest.advanceTimersByTime(10_000)
    expect(ws.closed).not.toBeNull()
    jest.advanceTimersByTime(500)
    expect(last()).not.toBe(ws)
    expect(last().params["phx:resume"]).toBe("1")
    // the LongPoll we fall back to uses the timeout
    expect(socket.conn.timeout).toBe(60_000)
  })
})
