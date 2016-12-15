import assert from "assert"

import jsdom from "jsdom"
import sinon from "sinon"
import {WebSocket, Server as WebSocketServer} from "mock-socket"

import {Channel, Push, Socket} from "../static/js/phoenix"

let channel, socket
// let chan = new Channel(topic, chanParams, this)

describe("constructor", () => {
  it("sets defaults", () => {
    socket = { timeout: 1234 }
    channel = new Channel("topic", { one: "two" }, socket)

    assert.equal(channel.state, "closed")
    assert.equal(channel.topic, "topic")
    assert.deepEqual(channel.params, { one: "two" })
    assert.deepEqual(channel.socket, socket)
    assert.equal(channel.timeout, 1234)
    assert.equal(channel.joinedOnce, false)
    assert.ok(channel.joinPush)
    assert.deepEqual(channel.pushBuffer, [])
  })
})
