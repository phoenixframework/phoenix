import assert from "assert"

import jsdom from "jsdom"
import sinon from "sinon"
import {WebSocket, Server as WebSocketServer} from "mock-socket"

import {Channel, Socket} from "../static/js/phoenix"

let channel, socket, push
// let chan = new Channel(topic, chanParams, this)

describe("constructor", () => {
  it("sets defaults", () => {
    socket = { timeout: 1234 }
    channel = new Channel("topic", { one: "two" }, socket)
    push = channel.joinPush

    assert.equal(channel.state, "closed")
    assert.equal(channel.topic, "topic")
    assert.deepEqual(channel.params, { one: "two" })
    assert.deepEqual(channel.socket, socket)
    assert.equal(channel.timeout, 1234)
    assert.equal(channel.joinedOnce, false)
    assert.ok(channel.joinPush)
    assert.deepEqual(channel.pushBuffer, [])
  })

  it("sets up joinPush object", () => {
    socket = { timeout: 1234 }
    channel = new Channel("topic", { one: "two" }, socket)
    push = channel.joinPush

    assert.deepEqual(push.channel, channel)
    assert.deepEqual(push.payload, { one: "two" })
    assert.equal(push.event, "phx_join")
    assert.equal(push.timeout, 1234)
  })
})

describe("join", () => {
  beforeEach(() => {
    socket = new Socket("/socket", { timeout: 1000 })
    sinon.stub(socket, "makeRef", () => { return 1 })

    channel = new Channel("topic", { one: "two" }, socket)
  })

  it("sets state to joining", () => {
    channel.join()

    assert.equal(channel.state, "joining")
  })

  it("sets joinedOnce to true", () => {
    assert.ok(!channel.joinedOnce)

    channel.join()

    assert.ok(channel.joinedOnce)
  })

  it("throws if attempting to join multiple times", () => {
    channel.join()

    assert.throws(() => channel.join(), /tried to join multiple times/)
  })

  it("triggers socket push", () => {
    const spy = sinon.spy(socket, "push")

    channel.join()

    assert.ok(spy.calledOnce)
    assert.ok(spy.calledWith({
      topic: "topic",
      event: "phx_join",
      payload: { one: "two" },
      ref: 1,
    }))
  })
})
