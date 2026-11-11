import {jest} from "@jest/globals"
import {LongPoll, ResumableWebSocket, Socket} from "../js/phoenix"
import {SOCKET_STATES} from "../js/phoenix/constants"
import Ajax from "../js/phoenix/ajax"

const control = (event, payload) => JSON.stringify([null, null, "phoenix", event, payload])
const reply = (joinRef, ref, topic, status, response) =>
  JSON.stringify([joinRef, ref, topic, "phx_reply", {status, response}])

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
const last = () => FakeWebSocket.instances.at(-1)
const events = ws => ws.sent.filter(data => !data.startsWith("[null,null,\"phoenix\",\"phx_")).map(data => JSON.parse(data))

describe("Socket.attachSession", () => {
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

  it("switches a socket with the browser's WebSocket to ResumableWebSocket", () => {
    socket = new Socket("ws://localhost/socket")
    expect(socket.attachSession("token")).toBe(true)
    expect(socket.transport).toBe(ResumableWebSocket)
  })

  it("does not attach with a transport that cannot resume sessions", () => {
    class CustomTransport extends FakeWebSocket {}
    socket = new Socket("ws://localhost/socket", {transport: CustomTransport})
    expect(socket.attachSession("token")).toBe(false)
    expect(socket.transport).toBe(CustomTransport)
  })

  it("attaches to the session and receives the replies of the joins the server sent", () => {
    socket = new Socket("ws://localhost/socket")
    socket.attachSession("token")
    const channel = socket.channel("room:a", {a: 1})
    const replies = []
    channel.awaitJoin("phx-1").receive("ok", response => replies.push(response))
    socket.connect()

    const ws = last()
    expect(ws.params).toEqual({vsn: "2.0.0", "phx:resumable": "1", "phx:resume": "1"})
    ws.open()
    expect(ws.sent).toEqual([control("phx_resume", {token: "token", ack: 0})])
    expect(socket.isConnected()).toBe(false)

    ws.receive(control("phx_resumed", {seq: 0, last: 2}))
    expect(socket.isConnected()).toBe(true)
    ws.receive(reply("phx-1", "phx-1", "room:a", "ok", {rendered: true}))
    expect(replies).toEqual([{rendered: true}])
    expect(channel.isJoined()).toBe(true)

    // the client does not join, and pushes with the join ref of the server
    channel.push("event", {})
    expect(events(ws).map(([joinRef, , topic, event]) => [joinRef, topic, event]))
      .toEqual([["phx-1", "room:a", "event"]])
  })

  it("delivers the messages the channel received before the client attached", () => {
    socket = new Socket("ws://localhost/socket")
    socket.attachSession("token")
    const channel = socket.channel("room:a")
    const pushes = []
    channel.on("pushed", payload => pushes.push(payload))
    channel.awaitJoin("phx-1")
    socket.connect()
    last().open()
    last().receive(control("phx_resumed", {seq: 0, last: 2}))
    last().receive(reply("phx-1", "phx-1", "room:a", "ok", {}))
    last().receive(JSON.stringify(["phx-1", null, "room:a", "pushed", {n: 1}]))
    expect(pushes).toEqual([{n: 1}])
  })

  it("can await joins after connecting, until the socket attached", () => {
    socket = new Socket("ws://localhost/socket")
    socket.attachSession("token")
    socket.connect()
    const channel = socket.channel("room:a")
    channel.awaitJoin("phx-1")
    last().open()
    last().receive(control("phx_resumed", {seq: 0, last: 1}))
    last().receive(reply("phx-1", "phx-1", "room:a", "ok", {}))
    expect(channel.isJoined()).toBe(true)

    // the replies of the server are gone, so later channels join
    const later = socket.channel("room:b")
    later.awaitJoin("phx-2")
    expect(events(last()).map(([, , topic, event]) => [topic, event])).toEqual([["room:b", "phx_join"]])
  })

  it("joins when the socket does not attach", () => {
    socket = new Socket("ws://localhost/socket")
    const channel = socket.channel("room:a")
    channel.awaitJoin("phx-1")
    socket.connect()
    last().open()
    expect(events(last()).map(([, , topic, event]) => [topic, event])).toEqual([["room:a", "phx_join"]])
    expect(channel.joinRef()).not.toBe("phx-1")
  })

  it("connects with a new session and joins when the session is gone", () => {
    socket = new Socket("ws://localhost/socket")
    socket.attachSession("token")
    const channel = socket.channel("room:a", {a: 1})
    channel.awaitJoin("phx-1")
    socket.connect()
    last().open()
    last().receive(control("phx_gone", {}))
    expect(socket.isConnected()).toBe(false)

    jest.advanceTimersByTime(10)
    const ws = last()
    expect(ws.params).toEqual({vsn: "2.0.0", "phx:resumable": "1"})
    ws.open()
    ws.receive(control("phx_session", {token: "new"}))
    expect(events(ws).map(([, , topic, event, payload]) => [topic, event, payload]))
      .toEqual([["room:a", "phx_join", {a: 1}]])
  })

  it("connects with a new session when the server does not answer", () => {
    socket = new Socket("ws://localhost/socket")
    socket.attachSession("token")
    const channel = socket.channel("room:a")
    channel.awaitJoin("phx-1")
    socket.connect()
    const ws = last()
    ws.open()

    jest.advanceTimersByTime(10_000)
    expect(ws.closed).not.toBeNull()
    jest.advanceTimersByTime(10)
    expect(last()).not.toBe(ws)
    expect(last().params["phx:resume"]).toBeUndefined()
    last().open()
    expect(events(last()).map(([, , topic, event]) => [topic, event])).toEqual([["room:a", "phx_join"]])
  })

  it("reports an error when the WebSocket fails before it attached", () => {
    socket = new Socket("ws://localhost/socket")
    const errors = []
    socket.onError(error => errors.push(error))
    socket.attachSession("token")
    socket.connect()
    last().onerror("failed")
    expect(errors).toEqual(["failed"])
  })

  describe("with long polling", () => {
    let polls

    beforeEach(() => {
      polls = []
      jest.spyOn(Ajax, "request").mockImplementation((method, url, headers, body, timeout, ontimeout, callback) => {
        polls.push({method, params: Object.fromEntries(new URL(url).searchParams), headers, body, callback})
        return {abort: jest.fn()}
      })
    })

    afterEach(() => jest.restoreAllMocks())

    it("attaches to the session with the first poll", () => {
      socket = new Socket("ws://localhost/socket", {transport: LongPoll})
      expect(socket.attachSession("token")).toBe(true)
      const channel = socket.channel("room:a")
      const replies = []
      channel.awaitJoin("phx-1").receive("ok", response => replies.push(response))
      socket.connect()
      jest.advanceTimersByTime(0)

      expect(polls).toHaveLength(1)
      expect(polls[0].params).toEqual({vsn: "2.0.0", "phx:ack": "0", "phx:resume": "1"})
      expect(polls[0].headers["X-Phoenix-Longpoll-Token"]).toBe("token")

      polls[0].callback({
        status: 200,
        token: "token",
        messages: [reply("phx-1", "phx-1", "room:a", "ok", {rendered: true})],
        last: 1
      })
      expect(socket.isConnected()).toBe(true)
      jest.advanceTimersByTime(0)
      expect(replies).toEqual([{rendered: true}])
      expect(polls.at(-1).params).toEqual({vsn: "2.0.0", "phx:ack": "1"})
    })

    it("connects with a new session and joins when the session is gone", () => {
      socket = new Socket("ws://localhost/socket", {transport: LongPoll})
      socket.attachSession("token")
      const channel = socket.channel("room:a")
      channel.awaitJoin("phx-1")
      socket.connect()
      jest.advanceTimersByTime(0)
      polls[0].callback({status: 410})

      // the socket connects again, and the new LongPoll polls on the next tick
      jest.advanceTimersByTime(20)
      const poll = polls.at(-1)
      expect(poll.params).toEqual({vsn: "2.0.0"})
      expect(poll.headers["X-Phoenix-Longpoll-Token"]).toBeUndefined()
      poll.callback({status: 410, token: "new", messages: [], last: 0})
      jest.advanceTimersByTime(0)

      const post = polls.find(({method}) => method === "POST")
      expect(JSON.parse(post.body).slice(2, 4)).toEqual(["room:a", "phx_join"])
    })
  })
})
