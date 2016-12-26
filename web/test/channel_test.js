import assert from "assert"

import jsdom from "jsdom"
import sinon from "sinon"
import {WebSocket, Server as WebSocketServer} from "mock-socket"

import {Channel, Socket} from "../static/js/phoenix"

let channel, socket, push
// let chan = new Channel(topic, chanParams, this)

describe("constructor", () => {
  beforeEach(() => {
    socket = { timeout: 1234 }
  })

  it("sets defaults", () => {
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

  it("sets up joinPush object", () => {
    channel = new Channel("topic", { one: "two" }, socket)
    push = channel.joinPush

    assert.deepEqual(push.channel, channel)
    assert.deepEqual(push.payload, { one: "two" })
    assert.equal(push.event, "phx_join")
    assert.equal(push.timeout, 1234)
  })
})

describe("join", () => {
  const defaultTimeout = 1000
  const defaultRef = 1

  beforeEach(() => {
    socket = new Socket("/socket", { timeout: defaultTimeout })
    sinon.stub(socket, "makeRef", () => { return defaultRef })

    channel = socket.channel("topic", { one: "two" })
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

  it("triggers socket push with channel params", () => {
    const spy = sinon.spy(socket, "push")

    channel.join()

    assert.ok(spy.calledOnce)
    assert.ok(spy.calledWith({
      topic: "topic",
      event: "phx_join",
      payload: { one: "two" },
      ref: defaultRef,
    }))
  })

  it("can set timeout on joinPush", () => {
    const newTimeout = 2000
    const joinPush = channel.joinPush

    assert.equal(joinPush.timeout, defaultTimeout)

    channel.join(newTimeout)

    assert.equal(joinPush.timeout, newTimeout)
  })

  it("sets joinPush refEventName", () => {
    const joinPush = channel.joinPush

    assert.equal(joinPush.refEvent, null)

    channel.join()

    assert.equal(joinPush.refEvent, "chan_reply_1")
  })
})

describe("joinPush", () => {
  let joinPush, clock, response

  const helpers = {
    receiveOk() {
      clock.tick(channel.timeout / 2) // before timeout
      return channel.trigger("chan_reply_1", { status: "ok", response }, 1)
    },

    receiveTimeout() {
      clock.tick(channel.timeout * 2) // after timeout
    },

    receiveError() {
      clock.tick(channel.timeout / 2) // before timeout
      return channel.trigger("chan_reply_1", { status: "error", response }, 1)
    },

    getBindings(event) {
      return channel.bindings.filter(bind => bind.event === event )
    }
  }

  beforeEach(() => {
    clock = sinon.useFakeTimers()

    socket = new Socket("/socket", { timeout: 1000 })
    sinon.stub(socket, "makeRef", () => { return 1 })

    channel = socket.channel("topic", { one: "two" })
    joinPush = channel.joinPush

    channel.join()
  })

  afterEach(() => {
    clock.restore()
  })

  describe("receives 'ok'", () => {
    beforeEach(() => {
      response = { chan: "reply" }
    })

    it("sets channel state to joined", () => {
      assert.notEqual(channel.state, "joined")

      helpers.receiveOk()

      assert.equal(channel.state, "joined")
    })

    it("triggers receive('ok') callback after ok response", () => {
      const spyOk = sinon.spy()

      joinPush.receive("ok", spyOk)

      helpers.receiveOk()

      assert.ok(spyOk.calledOnce)
    })

    it("triggers receive('ok') callback if ok response already received", () => {
      const spyOk = sinon.spy()

      helpers.receiveOk()

      joinPush.receive("ok", spyOk)

      assert.ok(spyOk.calledOnce)
    })

    it("does not trigger other receive callbacks after ok response", () => {
      const spyError = sinon.spy()
      const spyTimeout = sinon.spy()

      joinPush
        .receive("error", spyError)
        .receive("timeout", spyTimeout)

      helpers.receiveOk()
      clock.tick(channel.timeout * 2) // attempt timeout

      assert.ok(!spyError.called)
      assert.ok(!spyTimeout.called)
    })

    it("clears timeoutTimer", () => {
      assert.ok(joinPush.timeoutTimer)

      helpers.receiveOk()

      assert.equal(joinPush.timeoutTimer, null)
    })

    it("sets receivedResp", () => {
      assert.equal(joinPush.receivedResp, null)

      helpers.receiveOk()

      assert.deepEqual(joinPush.receivedResp, { status: "ok", response })
    })

    it("removes channel bindings", () => {
      let bindings = helpers.getBindings("chan_reply_1")
      assert.equal(bindings.length, 1)

      helpers.receiveOk()

      bindings = helpers.getBindings("chan_reply_1")
      assert.equal(bindings.length, 0)
    })

    it("sets channel state to joined", () => {
      helpers.receiveOk()

      assert.equal(channel.state, "joined")
    })

    it("resets channel rejoinTimer", () => {
      assert.ok(channel.rejoinTimer)

      const spy = sinon.spy(channel.rejoinTimer, "reset")

      helpers.receiveOk()

      assert.ok(spy.calledOnce)
    })

    it("sends and empties channel's buffered pushEvents", () => {
      const pushEvent = { send: () => {} }
      const spy = sinon.spy(pushEvent, "send")

      channel.pushBuffer.push(pushEvent)

      helpers.receiveOk()

      assert.ok(spy.calledOnce)
      assert.equal(channel.pushBuffer.length, 0)
    })
  })

  describe("receives 'timeout'", () => {
    it("sets channel state to errored", () => {
      helpers.receiveTimeout()

      assert.equal(channel.state, "errored")
    })

    it("triggers receive('timeout') callback after ok response", () => {
      const spyTimeout = sinon.spy()

      joinPush.receive("timeout", spyTimeout)

      helpers.receiveTimeout()

      assert.ok(spyTimeout.calledOnce)
    })

    it("triggers receive('timeout') callback if already timed out", () => {
      const spyTimeout = sinon.spy()

      helpers.receiveTimeout()

      joinPush.receive("timeout", spyTimeout)

      assert.ok(spyTimeout.calledOnce)
    })

    it("does not trigger other receive callbacks after timeout response", () => {
      const spyOk = sinon.spy()
      const spyError = sinon.spy()

      joinPush
        .receive("ok", spyOk)
        .receive("error", spyError)

      helpers.receiveTimeout()
      helpers.receiveOk()

      assert.ok(!spyOk.called)
      assert.ok(!spyError.called)
    })

    it("schedules rejoinTimer timeout", () => {
      assert.ok(channel.rejoinTimer)

      const spy = sinon.spy(channel.rejoinTimer, "scheduleTimeout")

      helpers.receiveTimeout()

      assert.ok(spy.called) // TODO why called multiple times?
    })

    it("cannot send after timeout", () => {
      const spy = sinon.spy(socket, "push")

      helpers.receiveTimeout()

      joinPush.send()

      assert.ok(!spy.called)
    })

    it("sets receivedResp", () => {
      assert.equal(joinPush.receivedResp, null)

      helpers.receiveTimeout()

      assert.deepEqual(joinPush.receivedResp, { status: "timeout", response: {} })
    })
  })

  describe("receives 'error'", () => {
    beforeEach(() => {
      response = { chan: "fail" }
    })

    it("triggers receive('error') callback after error response", () => {
      const spyError = sinon.spy()

      joinPush.receive("error", spyError)

      helpers.receiveError()

      assert.ok(spyError.calledOnce)
    })

    it("triggers receive('error') callback if error response already received", () => {
      const spyError = sinon.spy()

      helpers.receiveError()

      joinPush.receive("error", spyError)

      assert.ok(spyError.calledOnce)
    })

    it("does not trigger other receive callbacks after ok response", () => {
      const spyOk = sinon.spy()
      const spyTimeout = sinon.spy()

      joinPush
        .receive("ok", spyOk)
        .receive("timeout", spyTimeout)

      helpers.receiveError()
      clock.tick(channel.timeout * 2) // attempt timeout

      assert.ok(!spyOk.called)
      assert.ok(!spyTimeout.called)
    })

    it("clears timeoutTimer", () => {
      assert.ok(joinPush.timeoutTimer)

      helpers.receiveError()

      assert.equal(joinPush.timeoutTimer, null)
    })

    it("sets receivedResp", () => {
      assert.equal(joinPush.receivedResp, null)

      helpers.receiveError()

      assert.deepEqual(joinPush.receivedResp, { status: "error", response })
    })

    it("removes channel bindings", () => {
      let bindings = helpers.getBindings("chan_reply_1")
      assert.equal(bindings.length, 1)

      helpers.receiveError()

      bindings = helpers.getBindings("chan_reply_1")
      assert.equal(bindings.length, 0)
    })

    it("does not set channel state to joined", () => {
      helpers.receiveError()

      assert.equal(channel.state, "joining")
    })

    it("does not trigger channel's buffered pushEvents", () => {
      const pushEvent = { send: () => {} }
      const spy = sinon.spy(pushEvent, "send")

      channel.pushBuffer.push(pushEvent)

      helpers.receiveError()

      assert.ok(!spy.called)
      assert.equal(channel.pushBuffer.length, 1)
    })
  })
})

describe("onError", () => {
  let clock, joinPush

  beforeEach(() => {
    clock = sinon.useFakeTimers()

    socket = new Socket("/socket", { timeout: 1000 })
    sinon.stub(socket, "makeRef", () => { return 1 })
    sinon.stub(socket, "isConnected", () => { return true })
    sinon.stub(socket, "push", () => { return true })

    channel = socket.channel("topic", { one: "two" })

    joinPush = channel.joinPush

    channel.join()
  })

  afterEach(() => {
    clock.restore()
  })

  it("sets state to 'errored'", () => {
    assert.notEqual(channel.state, "errored")

    channel.trigger("phx_error")

    assert.equal(channel.state, "errored")
  })

  it("tries to rejoin with backoff", () => {
    const spy = sinon.stub(joinPush, "send")

    assert.equal(spy.callCount, 0)

    channel.trigger("phx_error")

    clock.tick(1000)
    assert.equal(spy.callCount, 1)

    clock.tick(2000)
    assert.equal(spy.callCount, 2)

    clock.tick(5000)
    assert.equal(spy.callCount, 3)

    clock.tick(10000)
    assert.equal(spy.callCount, 4)
  })

  it("does not rejoin if channel leaving", () => {
    channel.state = "leaving"

    const spy = sinon.stub(joinPush, "send")

    channel.trigger("phx_error")

    clock.tick(1000)
    assert.equal(spy.callCount, 0)

    clock.tick(2000)
    assert.equal(spy.callCount, 0)

    assert.equal(channel.state, "leaving")
  })

  it("does not rejoin if channel closed", () => {
    channel.state = "closed"

    const spy = sinon.stub(joinPush, "send")

    channel.trigger("phx_error")

    clock.tick(1000)
    assert.equal(spy.callCount, 0)

    clock.tick(2000)
    assert.equal(spy.callCount, 0)

    assert.equal(channel.state, "closed")
  })

  it("triggers additional callbacks", () => {
    const spy = sinon.spy()
    channel.onError(spy)

    assert.equal(spy.callCount, 0)

    channel.trigger("phx_error")

    assert.equal(spy.callCount, 1)
  })
})

describe("onClose", () => {
  let clock, joinPush

  beforeEach(() => {
    clock = sinon.useFakeTimers()

    socket = new Socket("/socket", { timeout: 1000 })
    sinon.stub(socket, "makeRef", () => { return 1 })
    sinon.stub(socket, "isConnected", () => { return true })
    sinon.stub(socket, "push", () => { return true })

    channel = socket.channel("topic", { one: "two" })

    joinPush = channel.joinPush

    channel.join()
  })

  afterEach(() => {
    clock.restore()
  })

  it("sets state to 'closed'", () => {
    assert.notEqual(channel.state, "closed")

    channel.trigger("phx_close")

    assert.equal(channel.state, "closed")
  })

  it("does not rejoin", () => {
    const spy = sinon.stub(joinPush, "send")

    channel.trigger("phx_close")

    clock.tick(1000)
    assert.equal(spy.callCount, 0)

    clock.tick(2000)
    assert.equal(spy.callCount, 0)
  })

  it("triggers additional callbacks", () => {
    const spy = sinon.spy()
    channel.onClose(spy)

    assert.equal(spy.callCount, 0)

    channel.trigger("phx_close")

    assert.equal(spy.callCount, 1)
  })

  it("removes channel from socket", () => {
    assert.equal(socket.channels.length, 1)
    assert.equal(channel, socket.channels[0])

    channel.trigger("phx_close")

    assert.equal(socket.channels.length, 0)
  })
})

describe("onMessage", () => {
  beforeEach(() => {
    socket = new Socket("/socket", { timeout: 1000 })

    channel = socket.channel("topic", { one: "two" })
  })

  it("returns payload by default", () => {
    const ref = 1
    const payload = channel.onMessage("event", { one: "two" }, ref)

    assert.deepEqual(payload, { one: "two" })
  })
})

describe("canPush", () => {
  beforeEach(() => {
    socket = new Socket("/socket", { timeout: 1000 })

    channel = socket.channel("topic", { one: "two" })
  })

  it("returns true when socket connected and channel joined", () => {
    sinon.stub(socket, "isConnected").returns(true)
    channel.state = "joined"

    assert.ok(channel.canPush())
  })

  it("otherwise returns false", () => {
    const isConnectedStub = sinon.stub(socket, "isConnected")

    isConnectedStub.returns(false)
    channel.state = "joined"

    assert.ok(!channel.canPush())

    isConnectedStub.returns(true)
    channel.state = "joining"

    assert.ok(!channel.canPush())

    isConnectedStub.returns(false)
    channel.state = "joining"

    assert.ok(!channel.canPush())
  })
})
