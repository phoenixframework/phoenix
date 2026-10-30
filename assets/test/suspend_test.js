import {jest} from "@jest/globals"
import {Socket} from "../js/phoenix"
import {SOCKET_STATES} from "../js/phoenix/constants"

class Transport {
  constructor(){ this.readyState = SOCKET_STATES.connecting }
  send(){}
  close(){ this.readyState = SOCKET_STATES.closed }
  open(){ this.readyState = SOCKET_STATES.open; this.onopen() }
}

describe("transport suspension", () => {
  let socket, channel, transport, events

  beforeEach(() => {
    jest.useFakeTimers()
    events = []
    socket = new Socket("/socket", {transport: Transport})
    socket.onSuspend(() => events.push("suspend"))
    socket.onResume(() => events.push("resume"))
    socket.connect()
    transport = socket.conn
    transport.open()
    channel = socket.channel("room")
    channel.onError(() => events.push("error"))
    channel.join()
    transport.onmessage({data: JSON.stringify([
      channel.joinRef(), channel.joinRef(), "room", "phx_reply", {status: "ok", response: {}}
    ])})
  })

  afterEach(() => {
    socket.disconnect()
    jest.useRealTimers()
  })

  it("preserves the join and delivers one notification per transition", () => {
    const joinRef = channel.joinRef()
    transport.onsuspend()
    transport.onsuspend()
    expect(events).toEqual(["suspend"])
    expect(channel.canPush()).toBe(true)
    transport.onresume()
    transport.onresume()
    expect(events).toEqual(["suspend", "resume"])
    expect(channel.joinRef()).toBe(joinRef)
  })

  it("errors the channel if the suspended transport loses its session", () => {
    transport.onsuspend()
    transport.close()
    transport.onclose({code: 3410})
    transport.onresume()
    expect(events).toEqual(["suspend", "error"])
    expect(channel.isErrored()).toBe(true)
  })

  it("ignores events from a replaced transport", () => {
    transport.onsuspend()
    socket.disconnect()
    socket.connect()
    socket.conn.open()
    events = []
    transport.onsuspend()
    transport.onresume()
    expect(events).toEqual([])
  })

  it("allows removing callbacks with off", () => {
    const callback = jest.fn()
    socket.off([socket.onSuspend(callback), socket.onResume(callback)])
    transport.onsuspend()
    transport.onresume()
    expect(callback).not.toHaveBeenCalled()
  })

  it("stops notifying when a callback disconnects", () => {
    socket.onSuspend(() => socket.disconnect())
    const callback = jest.fn()
    socket.onSuspend(callback)
    transport.onsuspend()
    expect(callback).not.toHaveBeenCalled()
  })
})
