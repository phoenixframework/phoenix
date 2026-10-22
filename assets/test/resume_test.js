import {jest} from "@jest/globals"
import {Socket} from "../js/phoenix"
import {SOCKET_STATES} from "../js/phoenix/constants"

let connections

class StubWebSocket {
  constructor(url){
    this.url = url
    this.readyState = SOCKET_STATES.connecting
    this.sent = []
    connections.push(this)
  }
  send(data){ this.sent.push(JSON.parse(data)) }
  close(){ this.readyState = SOCKET_STATES.closed }
  open(){
    this.readyState = SOCKET_STATES.open
    this.onopen()
  }
  drop(){
    this.readyState = SOCKET_STATES.closed
    this.onclose({code: 1006})
  }
  receive(message){ this.onmessage({data: JSON.stringify(message)}) }
}

const sent = (conn, event) => conn.sent.filter(([, , , e]) => e === event)

describe("resumable channels", () => {
  let socket, channel, conn, joinRef, events

  beforeEach(() => {
    jest.useFakeTimers()
    connections = []
    socket = new Socket("/socket", {transport: StubWebSocket, resumable: true, reconnectAfterMs: () => 10})
    socket.connect()
    conn = connections[0]
    conn.open()

    events = []
    channel = socket.channel("room")
    channel.onError(() => events.push("error"))
    channel.onSuspend(reason => events.push(["suspend", reason]))
    channel.onResume(() => events.push("resume"))
    channel.join()

    const [ref, pushRef] = sent(conn, "phx_join")[0]
    joinRef = ref
    conn.receive([joinRef, pushRef, "room", "phx_reply", {status: "ok", response: {}}])
    conn.receive([joinRef, null, "room", "phx_resumable", {token: "token"}])
  })

  afterEach(() => {
    socket.disconnect()
    jest.useRealTimers()
  })

  // the server replies to the resume with the channels it resumed
  const resume = (conn, response) => {
    const [, ref] = sent(conn, "phx_resume")[0]
    conn.receive([null, ref, "phoenix", "phx_reply", response])
  }

  const reconnect = () => {
    conn.drop()
    jest.advanceTimersByTime(10)
    const next = connections.at(-1)
    next.open()
    return next
  }

  it("asks the server to make channels resumable", () => {
    expect(conn.url).toContain("phx_resumable=true")
  })

  it("acknowledges the frames it received for the join", () => {
    conn.receive([joinRef, null, "room", "tick", {}])
    conn.receive([joinRef, null, "room", "tick", {}])
    // frames of other joins don't count
    conn.receive(["other", null, "room", "tick", {}])
    expect(sent(conn, "phx_ack")).toEqual([])

    jest.advanceTimersByTime(1000)

    expect(sent(conn, "phx_ack").map(([, , , , payload]) => payload)).toEqual([
      {channels: [["room", joinRef, 2]]}
    ])
  })

  it("suspends the channel when the connection drops and resumes it on the next one", () => {
    conn.receive([joinRef, null, "room", "tick", {}])
    channel.push("ping", {n: 1})
    const [, pingRef] = sent(conn, "ping")[0]

    const next = reconnect()

    expect(events).toEqual([["suspend", "connection_closed"]])
    expect(next.sent[0]).toEqual([
      null, expect.any(String), "phoenix", "phx_resume",
      {token: "token", channels: [["room", joinRef, 1]]}
    ])
    expect(sent(next, "phx_join")).toEqual([])

    resume(next, {status: "ok", response: {channels: [["room", joinRef]]}})

    expect(events).toEqual([["suspend", "connection_closed"], "resume"])
    // the server drops the ping if it handled it already, and replays its reply
    expect(sent(next, "ping")).toEqual([[joinRef, pingRef, "room", "ping", {n: 1}]])
  })

  it("rejoins the channel when the resume fails", () => {
    const next = reconnect()
    resume(next, {status: "error", response: {reason: "invalid_token"}})

    expect(events).toEqual([["suspend", "connection_closed"], "error"])
    jest.advanceTimersByTime(1000)
    expect(sent(next, "phx_join")).toHaveLength(1)
    expect(socket.resumeToken).toBeNull()
  })

  it("keeps the channel like any other once the session released it to the connection", () => {
    const next = reconnect()
    resume(next, {status: "ok", response: {channels: [["room", joinRef]], released: true}})

    expect(events).toEqual([["suspend", "connection_closed"], "resume"])
    expect(socket.resumeToken).toBeNull()

    // the connection keeps the channel itself, so we don't acknowledge
    next.receive([joinRef, null, "room", "tick", {}])
    jest.advanceTimersByTime(1000)
    expect(sent(next, "phx_ack")).toEqual([])

    // and it errors when the connection drops
    next.drop()
    expect(events).toEqual([["suspend", "connection_closed"], "resume", "error"])
  })

  it("tells the channels when the transport is interrupted without suspending them", () => {
    conn.oninterrupt()

    expect(events).toEqual([["suspend", "connection_interrupted"]])
    expect(channel.canPush()).toBe(true)

    // a channel joined meanwhile was not interrupted
    const other = socket.channel("other")
    const otherEvents = []
    other.onResume(() => otherEvents.push("resume"))
    other.join()
    const [otherJoinRef, otherRef] = sent(conn, "phx_join").at(-1)
    conn.receive([otherJoinRef, otherRef, "other", "phx_reply", {status: "ok", response: {}}])

    conn.onrestore()

    expect(events).toEqual([["suspend", "connection_interrupted"], "resume"])
    expect(otherEvents).toEqual([])
  })

  it("does not resume a channel that left while the transport was interrupted", () => {
    conn.oninterrupt()
    channel.leave()
    conn.onrestore()

    expect(events).toEqual([["suspend", "connection_interrupted"]])
  })
})
