import assert from "assert"

import jsdom from "jsdom"
import sinon from "sinon"
import {WebSocket, Server as WebSocketServer} from "mock-socket"
import {encode, decode} from "./serializer"
import {Channel, Socket} from "../js/phoenix"

let channel, socket

const defaultRef = 1
const defaultTimeout = 10000

describe("constructor", () => {
  beforeEach(() => {
    socket = { timeout: 1234 }
  })

  it("sets defaults", () => {
    channel = new Channel("topic", { one: "two" }, socket)

    assert.equal(channel.state, "closed")
    assert.equal(channel.topic, "topic")
    assert.deepEqual(channel.params(), { one: "two" })
    assert.deepEqual(channel.socket, socket)
    assert.equal(channel.timeout, 1234)
    assert.equal(channel.joinedOnce, false)
    assert.ok(channel.joinPush)
    assert.deepEqual(channel.pushBuffer, [])
  })

  it("sets up joinPush objec with literal params", () => {
    channel = new Channel("topic", { one: "two" }, socket)
    const joinPush = channel.joinPush

    assert.deepEqual(joinPush.channel, channel)
    assert.deepEqual(joinPush.payload(), { one: "two" })
    assert.equal(joinPush.event, "phx_join")
    assert.equal(joinPush.timeout, 1234)
  })

  it("sets up joinPush objec with closure params", () => {
    channel = new Channel("topic", function(){ return({one: "two"}) }, socket)
    const joinPush = channel.joinPush

    assert.deepEqual(joinPush.channel, channel)
    assert.deepEqual(joinPush.payload(), { one: "two" })
    assert.equal(joinPush.event, "phx_join")
    assert.equal(joinPush.timeout, 1234)
  })

})

describe("updating join params", () => {
  beforeEach(() => {
    socket = { timeout: 1234 }
  })

  it("can update the join params", () => {
    let counter = 0
    let params = function(){ return({value: counter}) }

    channel = new Channel("topic", params, socket)
    const joinPush = channel.joinPush

    assert.deepEqual(joinPush.channel, channel)
    assert.deepEqual(joinPush.payload(), { value: 0 })
    assert.equal(joinPush.event, "phx_join")
    assert.equal(joinPush.timeout, 1234)

    counter++

    assert.deepEqual(joinPush.channel, channel)
    assert.deepEqual(joinPush.payload(), { value: 1 })
    assert.deepEqual(channel.params(), { value: 1 })
    assert.equal(joinPush.event, "phx_join")
    assert.equal(joinPush.timeout, 1234)
  });
});

describe("join", () => {
  beforeEach(() => {
    socket = new Socket("/socket", { timeout: defaultTimeout })

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
    sinon.stub(socket, "makeRef", () => defaultRef)
    const spy = sinon.spy(socket, "push")

    channel.join()

    assert.ok(spy.calledOnce)
    assert.ok(spy.calledWith({
      topic: "topic",
      event: "phx_join",
      payload: { one: "two" },
      ref: defaultRef,
      join_ref: channel.joinRef()
    }))
  })

  it("can set timeout on joinPush", () => {
    const newTimeout = 2000
    const joinPush = channel.joinPush

    assert.equal(joinPush.timeout, defaultTimeout)

    channel.join(newTimeout)

    assert.equal(joinPush.timeout, newTimeout)
  })

  describe("timeout behavior", () => {
    let clock, joinPush

    const helpers = {
      receiveSocketOpen() {
        sinon.stub(socket, "isConnected", () => true)
        socket.onConnOpen()
      }
    }

    beforeEach(() => {
      clock = sinon.useFakeTimers()
      joinPush = channel.joinPush
    })

    afterEach(() => {
      clock.restore()
    })

    it("succeeds before timeout", () => {
      const spy = sinon.stub(socket, "push")
      const timeout = joinPush.timeout

      socket.connect()
      helpers.receiveSocketOpen()

      channel.join()
      assert.equal(spy.callCount, 1)

      clock.tick(timeout / 2)

      joinPush.trigger("ok", {})

      assert.equal(channel.state, "joined")

      clock.tick(timeout)
      assert.equal(spy.callCount, 1)
    })

    it("retries with backoff after timeout", () => {
      const spy = sinon.stub(socket, "push")
      const timeout = joinPush.timeout
      let callCount = 1

      socket.connect()
      helpers.receiveSocketOpen()

      channel.join()
      assert.equal(spy.callCount, callCount)

      clock.tick(timeout)
      assert.equal(spy.callCount, ++callCount) // leave pushed to server

      clock.tick(1000)
      assert.equal(spy.callCount, ++callCount)

      clock.tick(2000)
      assert.equal(spy.callCount, ++callCount)

      clock.tick(5000)
      assert.equal(spy.callCount, ++callCount)

      clock.tick(10000)
      assert.equal(spy.callCount, ++callCount)

      console.log("test: joinPush.trigger ok")
      joinPush.trigger("ok", {})
      assert.equal(channel.state, "joined")

      clock.tick(10000)
      assert.equal(spy.callCount, callCount)
      assert.equal(channel.state, "joined")
    })

    it("with socket and join delay", () => {
      const spy = sinon.stub(socket, "push")
      const clock = sinon.useFakeTimers()
      const joinPush = channel.joinPush

      channel.join()
      assert.equal(spy.callCount, 1)

      // open socket after delay
      clock.tick(9000)

      assert.equal(spy.callCount, 1)

      // join request returns between timeouts
      clock.tick(1000)
      socket.connect()
      helpers.receiveSocketOpen()
      joinPush.trigger("ok", {})

      assert.equal(channel.state, "errored")

      // join request succeeds after delay
      clock.tick(1000)

      assert.equal(channel.state, "joining")

      joinPush.trigger("ok", {})

      assert.equal(channel.state, "joined")
      assert.equal(spy.callCount, 3) // leave pushed to server
    })

    it("with socket delay only", () => {
      const spy = sinon.stub(socket, "push")
      const clock = sinon.useFakeTimers()
      const joinPush = channel.joinPush

      channel.join()

      // connect socket after delay
      clock.tick(6000)
      socket.connect()

      // open socket after delay
      clock.tick(5000)
      helpers.receiveSocketOpen()
      joinPush.trigger("ok", {})

      clock.tick(2000)
      assert.equal(channel.state, "joining")

      joinPush.trigger("ok", {})
      assert.equal(channel.state, "joined")
    })
  })
})

describe("joinPush", () => {
  let joinPush, clock, response

  const helpers = {
    receiveOk() {
      clock.tick(joinPush.timeout / 2) // before timeout
      return joinPush.trigger("ok", response)
    },

    receiveTimeout() {
      clock.tick(joinPush.timeout * 2) // after timeout
    },

    receiveError() {
      clock.tick(joinPush.timeout / 2) // before timeout
      return joinPush.trigger("error", response)
    },

    getBindings(event) {
      return channel.bindings.filter(bind => bind.event === event )
    }
  }

  beforeEach(() => {
    clock = sinon.useFakeTimers()

    socket = new Socket("/socket", { timeout: defaultTimeout })

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
      const pushEvent = { send() {} }
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

    socket = new Socket("/socket", { timeout: defaultTimeout })
    sinon.stub(socket, "isConnected", () => true)
    sinon.stub(socket, "push", () => true)

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

    socket = new Socket("/socket", { timeout: defaultTimeout })
    sinon.stub(socket, "isConnected", () => true)
    sinon.stub(socket, "push", () => true)

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
    assert.deepEqual(socket.channels[0], channel)

    channel.trigger("phx_close")

    assert.equal(socket.channels.length, 0)
  })
})

describe("onMessage", () => {
  beforeEach(() => {
    socket = new Socket("/socket")

    channel = socket.channel("topic", { one: "two" })
  })

  it("returns payload by default", () => {
    sinon.stub(socket, "makeRef", () => defaultRef)
    const payload = channel.onMessage("event", { one: "two" }, defaultRef)

    assert.deepEqual(payload, { one: "two" })
  })
})

describe("canPush", () => {
  beforeEach(() => {
    socket = new Socket("/socket")

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

describe("on", () => {
  beforeEach(() => {
    socket = new Socket("/socket")
    sinon.stub(socket, "makeRef", () => defaultRef)

    channel = socket.channel("topic", { one: "two" })
  })

  it("sets up callback for event", () => {
    const spy = sinon.spy()

    channel.trigger("event", {}, defaultRef)
    assert.ok(!spy.called)

    channel.on("event", spy)

    channel.trigger("event", {}, defaultRef)

    assert.ok(spy.called)
  })

  it("other event callbacks are ignored", () => {
    const spy = sinon.spy()
    const ignoredSpy = sinon.spy()

    channel.trigger("event", {}, defaultRef)

    assert.ok(!ignoredSpy.called)

    channel.on("event", spy)

    channel.trigger("event", {}, defaultRef)

    assert.ok(!ignoredSpy.called)
  })

  it("generates unique refs for callbacks", () => {
    const ref1 = channel.on("event1", () => 0)
    const ref2 = channel.on("event2", () => 0)
    assert.equal(ref1 + 1, ref2)
  })
})

describe("off", () => {
  beforeEach(() => {
    socket = new Socket("/socket")
    sinon.stub(socket, "makeRef", () => defaultRef)

    channel = socket.channel("topic", { one: "two" })
  })

  it("removes all callbacks for event", () => {
    const spy1 = sinon.spy()
    const spy2 = sinon.spy()
    const spy3 = sinon.spy()

    channel.on("event", spy1)
    channel.on("event", spy2)
    channel.on("other", spy3)

    channel.off("event")

    channel.trigger("event", {}, defaultRef)
    channel.trigger("other", {}, defaultRef)

    assert.ok(!spy1.called)
    assert.ok(!spy2.called)
    assert.ok(spy3.called)
  })

  it("removes callback by its ref", () => {
    const spy1 = sinon.spy()
    const spy2 = sinon.spy()

    const ref1 = channel.on("event", spy1)
    const ref2 = channel.on("event", spy2)

    channel.off("event", ref1)
    channel.trigger("event", {}, defaultRef)

    assert.ok(!spy1.called)
    assert.ok(spy2.called)
  })
})

describe("push", () => {
  let clock, joinPush
  let socketSpy

  let pushParams = (channel) => {
    return({
      topic: "topic",
      event: "event",
      payload: { foo: "bar" },
      join_ref: channel.joinRef(),
      ref: defaultRef
    })
  }

  beforeEach(() => {
    clock = sinon.useFakeTimers()

    socket = new Socket("/socket", { timeout: defaultTimeout })
    sinon.stub(socket, "makeRef", () => defaultRef)
    sinon.stub(socket, "isConnected", () => true)
    socketSpy = sinon.stub(socket, "push")

    channel = socket.channel("topic", { one: "two" })
  })

  afterEach(() => {
    clock.restore()
  })

  it("sends push event when successfully joined", () => {
    channel.join().trigger("ok", {})
    channel.push("event", { foo: "bar" })

    assert.ok(socketSpy.calledWith(pushParams(channel)))
  })

  it("enqueues push event to be sent once join has succeeded", () => {
    joinPush = channel.join()
    channel.push("event", { foo: "bar" })

    assert.ok(!socketSpy.calledWith(pushParams(channel)))

    clock.tick(channel.timeout / 2)
    joinPush.trigger("ok", {})

    assert.ok(socketSpy.calledWith(pushParams(channel)))
  })

  it("does not push if channel join times out", () => {
    joinPush = channel.join()
    channel.push("event", { foo: "bar" })

    assert.ok(!socketSpy.calledWith(pushParams(channel)))

    clock.tick(channel.timeout * 2)
    joinPush.trigger("ok", {})

    assert.ok(!socketSpy.calledWith(pushParams(channel)))
  })

  it("uses channel timeout by default", () => {
    const timeoutSpy = sinon.spy()
    channel.join().trigger("ok", {})

    channel.push("event", { foo: "bar" })
      .receive("timeout", timeoutSpy)

    clock.tick(channel.timeout / 2)
    assert.ok(!timeoutSpy.called)

    clock.tick(channel.timeout)
    assert.ok(timeoutSpy.called)
  })

  it("accepts timeout arg", () => {
    const timeoutSpy = sinon.spy()
    channel.join().trigger("ok", {})

    channel.push("event", { foo: "bar" }, channel.timeout * 2)
      .receive("timeout", timeoutSpy)

    clock.tick(channel.timeout)
    assert.ok(!timeoutSpy.called)

    clock.tick(channel.timeout * 2)
    assert.ok(timeoutSpy.called)
  })

  it("does not time out after receiving 'ok'", () => {
    channel.join().trigger("ok", {})
    const timeoutSpy = sinon.spy()
    const push = channel.push("event", { foo: "bar" })
    push.receive("timeout", timeoutSpy)

    clock.tick(push.timeout / 2)
    assert.ok(!timeoutSpy.called)

    push.trigger("ok", {})

    clock.tick(push.timeout)
    assert.ok(!timeoutSpy.called)
  })

  it("throws if channel has not been joined", () => {
    assert.throws(() => channel.push("event", {}), /tried to push.*before joining/)
  })
})

describe("leave", () => {
  let clock, joinPush
  let socketSpy

  beforeEach(() => {
    clock = sinon.useFakeTimers()

    socket = new Socket("/socket", { timeout: defaultTimeout })
    sinon.stub(socket, "isConnected", () => true)
    socketSpy = sinon.stub(socket, "push")

    channel = socket.channel("topic", { one: "two" })
    channel.join().trigger("ok", {})
  })

  afterEach(() => {
    clock.restore()
  })

  it("unsubscribes from server events", () => {
    sinon.stub(socket, "makeRef", () => defaultRef)
    const joinRef = channel.joinRef()

    channel.leave()

    assert.ok(socketSpy.calledWith({
      topic: "topic",
      event: "phx_leave",
      payload: {},
      ref: defaultRef,
      join_ref: joinRef
    }))
  })

  it("closes channel on 'ok' from server", () => {
    const anotherChannel = socket.channel("another", { three: "four" })
    assert.equal(socket.channels.length, 2)

    channel.leave().trigger("ok", {})

    assert.equal(socket.channels.length, 1)
    assert.deepEqual(socket.channels[0], anotherChannel)
  })

  it("sets state to closed on 'ok' event", () => {
    assert.notEqual(channel.state, "closed")

    channel.leave().trigger("ok", {})

    assert.equal(channel.state, "closed")
  })

  // TODO - the following tests are skipped until Channel.leave
  // behavior can be fixed; currently, 'ok' is triggered immediately
  // within Channel.leave so timeout callbacks are never reached
  //
  it.skip("sets state to leaving initially", () => {
    assert.notEqual(channel.state, "leaving")

    channel.leave()

    assert.equal(channel.state, "leaving")
  })

  it.skip("closes channel on 'timeout'", () => {
    channel.leave()

    clock.tick(channel.timeout)

    assert.equal(channel.state, "closed")
  })

  it.skip("accepts timeout arg", () => {
    channel.leave(channel.timeout * 2)

    clock.tick(channel.timeout)

    assert.equal(channel.state, "leaving")

    clock.tick(channel.timeout * 2)

    assert.equal(channel.state, "closed")
  })
})
