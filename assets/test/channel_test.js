import assert from "assert"

import sinon from "sinon"
import {Channel, Socket} from "../js/phoenix"

let channel, socket

const defaultRef = 1
const defaultTimeout = 10000

class WSMock {
  constructor(){}
  close(){}
  send(){}
}

describe("with transport", function(){
  before(function(){
    window.WebSocket = WSMock
  })

  after(function(done){
    window.WebSocket = null
    done()
  })

  describe("constructor", function(){
    beforeEach(function(){
      socket = new Socket("/", {timeout: 1234})
    })

    it("sets defaults", function(){
      channel = new Channel("topic", {one: "two"}, socket)

      assert.equal(channel.state, "closed")
      assert.equal(channel.topic, "topic")
      assert.deepEqual(channel.params(), {one: "two"})
      assert.deepEqual(channel.socket, socket)
      assert.equal(channel.timeout, 1234)
      assert.equal(channel.joinedOnce, false)
      assert.ok(channel.joinPush)
      assert.deepEqual(channel.pushBuffer, [])
    })

    it("sets up joinPush object with literal params", function(){
      channel = new Channel("topic", {one: "two"}, socket)
      const joinPush = channel.joinPush

      assert.deepEqual(joinPush.channel, channel)
      assert.deepEqual(joinPush.payload(), {one: "two"})
      assert.equal(joinPush.event, "phx_join")
      assert.equal(joinPush.timeout, 1234)
    })

    it("sets up joinPush object with closure params", function(){
      channel = new Channel("topic", function(){ return ({one: "two"}) }, socket)
      const joinPush = channel.joinPush

      assert.deepEqual(joinPush.channel, channel)
      assert.deepEqual(joinPush.payload(), {one: "two"})
      assert.equal(joinPush.event, "phx_join")
      assert.equal(joinPush.timeout, 1234)
    })

  })

  describe("updating join params", function(){
    it("can update the join params", function(){
      let counter = 0
      let params = function(){ return ({value: counter}) }
      socket = {timeout: 1234, onError: function(){}, onOpen: function(){}}

      channel = new Channel("topic", params, socket)
      const joinPush = channel.joinPush

      assert.deepEqual(joinPush.channel, channel)
      assert.deepEqual(joinPush.payload(), {value: 0})
      assert.equal(joinPush.event, "phx_join")
      assert.equal(joinPush.timeout, 1234)

      counter++

      assert.deepEqual(joinPush.channel, channel)
      assert.deepEqual(joinPush.payload(), {value: 1})
      assert.deepEqual(channel.params(), {value: 1})
      assert.equal(joinPush.event, "phx_join")
      assert.equal(joinPush.timeout, 1234)
    })
  })

  describe("join", function(){
    beforeEach(function(){
      socket = new Socket("/socket", {timeout: defaultTimeout})

      channel = socket.channel("topic", {one: "two"})
    })

    it("sets state to joining", function(){
      channel.join()

      assert.equal(channel.state, "joining")
    })

    it("sets joinedOnce to true", function(){
      assert.ok(!channel.joinedOnce)

      channel.join()

      assert.ok(channel.joinedOnce)
    })

    it("throws if attempting to join multiple times", function(){
      channel.join()

      assert.throws(() => channel.join(), /^Error: tried to join multiple times/)
    })

    it("triggers socket push with channel params", function(){
      sinon.stub(socket, "makeRef").callsFake(() => defaultRef)
      const spy = sinon.spy(socket, "push")

      channel.join()

      assert.ok(spy.calledOnce)
      assert.ok(spy.calledWith({
        topic: "topic",
        event: "phx_join",
        payload: {one: "two"},
        ref: defaultRef,
        join_ref: channel.joinRef()
      }))
    })

    it("can set timeout on joinPush", function(){
      const newTimeout = 2000
      const joinPush = channel.joinPush

      assert.equal(joinPush.timeout, defaultTimeout)

      channel.join(newTimeout)

      assert.equal(joinPush.timeout, newTimeout)
    })

    it("leaves existing duplicate topic on new join", function(done){
      channel.join()
        .receive("ok", () => {
          let newChannel = socket.channel("topic")
          assert.equal(channel.isJoined(), true)
          newChannel.join()
          assert.equal(channel.isJoined(), false)
          done()
        })

      channel.joinPush.trigger("ok", {})
    })

    describe("timeout behavior", function(){
      let clock, joinPush

      const helpers = {
        receiveSocketOpen(){
          sinon.stub(socket, "isConnected").callsFake(() => true)
          socket.onConnOpen()
        }
      }

      beforeEach(function(){
        clock = sinon.useFakeTimers()
        joinPush = channel.joinPush
      })

      afterEach(function(){
        clock.restore()
      })

      it("succeeds before timeout", function(){
        const spy = sinon.stub(socket, "push")
        const timeout = joinPush.timeout

        socket.connect()
        helpers.receiveSocketOpen()

        channel.join()
        assert.equal(spy.callCount, 1)


        assert.equal(channel.timeout, 10000)
        clock.tick(100)

        joinPush.trigger("ok", {})

        assert.equal(channel.state, "joined")

        clock.tick(timeout)
        assert.equal(spy.callCount, 1)
      })

      it("retries with backoff after timeout", function(){
        const spy = sinon.stub(socket, "push")
        const timeoutSpy = sinon.spy()
        const timeout = joinPush.timeout

        socket.connect()
        helpers.receiveSocketOpen()

        channel.join().receive("timeout", timeoutSpy)

        assert.equal(spy.callCount, 1)
        assert.equal(timeoutSpy.callCount, 0)

        clock.tick(timeout)
        assert.equal(spy.callCount, 2) // leave pushed to server
        assert.equal(timeoutSpy.callCount, 1)

        clock.tick(timeout + 1000)
        assert.equal(spy.callCount, 4) // leave + rejoin
        assert.equal(timeoutSpy.callCount, 2)

        clock.tick(10000)
        joinPush.trigger("ok", {})
        assert.equal(spy.callCount, 6)
        assert.equal(channel.state, "joined")
      })

      it("with socket and join delay", function(){
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

        assert.equal(channel.state, "errored")

        helpers.receiveSocketOpen()
        joinPush.trigger("ok", {})

        // join request succeeds after delay
        clock.tick(1000)

        assert.equal(channel.state, "joined")

        assert.equal(spy.callCount, 3) // leave pushed to server
      })

      it("with socket delay only", function(){
        const clock = sinon.useFakeTimers()
        const joinPush = channel.joinPush

        channel.join()

        assert.equal(channel.state, "joining")

        // connect socket after delay
        clock.tick(6000)
        socket.connect()

        // open socket after delay
        clock.tick(5000)
        helpers.receiveSocketOpen()
        joinPush.trigger("ok", {})

        joinPush.trigger("ok", {})
        assert.equal(channel.state, "joined")
      })
    })
  })

  describe("joinPush", function(){
    let joinPush, clock, response

    const helpers = {
      receiveOk(){
        clock.tick(joinPush.timeout / 2) // before timeout
        return joinPush.channel.trigger("phx_reply", {status: "ok", response: response}, joinPush.ref, joinPush.ref)
        // return joinPush.trigger("ok", response)
      },

      receiveTimeout(){
        clock.tick(joinPush.timeout * 2) // after timeout
      },

      receiveError(){
        clock.tick(joinPush.timeout / 2) // before timeout
        return joinPush.trigger("error", response)
      },

      getBindings(event){
        return channel.bindings.filter(bind => bind.event === event )
      }
    }

    beforeEach(function(){
      clock = sinon.useFakeTimers()

      socket = new Socket("/socket", {timeout: defaultTimeout})
      sinon.stub(socket, "isConnected").callsFake(() => true)
      sinon.stub(socket, "push").callsFake(() => true)

      channel = socket.channel("topic", {one: "two"})
      joinPush = channel.joinPush

      channel.join()
    })

    afterEach(function(){
      clock.restore()
    })

    describe("receives 'ok'", function(){
      beforeEach(function(){
        response = {chan: "reply"}
      })

      it("sets channel state to joined", function(){
        assert.notEqual(channel.state, "joined")

        helpers.receiveOk()

        assert.equal(channel.state, "joined")
      })

      it("triggers receive('ok') callback after ok response", function(){
        const spyOk = sinon.spy()

        joinPush.receive("ok", spyOk)

        helpers.receiveOk()

        assert.ok(spyOk.calledOnce)
      })

      it("triggers receive('ok') callback if ok response already received", function(){
        const spyOk = sinon.spy()

        helpers.receiveOk()

        joinPush.receive("ok", spyOk)

        assert.ok(spyOk.calledOnce)
      })

      it("does not trigger other receive callbacks after ok response", function(){
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

      it("clears timeoutTimer", function(){
        assert.ok(joinPush.timeoutTimer)

        helpers.receiveOk()

        assert.equal(joinPush.timeoutTimer, null)
      })

      it("sets receivedResp", function(){
        assert.equal(joinPush.receivedResp, null)

        helpers.receiveOk()

        assert.deepEqual(joinPush.receivedResp, {status: "ok", response})
      })

      it("removes channel bindings", function(){
        let bindings = helpers.getBindings("chan_reply_3")
        assert.equal(bindings.length, 1)

        helpers.receiveOk()

        bindings = helpers.getBindings("chan_reply_3")
        assert.equal(bindings.length, 0)
      })

      it("resets channel rejoinTimer", function(){
        assert.ok(channel.rejoinTimer)

        const spy = sinon.spy(channel.rejoinTimer, "reset")

        helpers.receiveOk()

        assert.ok(spy.calledOnce)
      })

      it("sends and empties channel's buffered pushEvents", function(done){
        const pushEvent = {send(){}}
        const spy = sinon.spy(pushEvent, "send")

        channel.pushBuffer.push(pushEvent)

        assert.equal(channel.state, "joining")
        joinPush.receive("ok", () => {
          assert.equal(spy.callCount, 1)
          assert.equal(channel.pushBuffer.length, 0)
          done()
        })
        helpers.receiveOk()
      })
    })

    describe("receives 'timeout'", function(){
      it("sets channel state to errored", function(done){
        joinPush.receive("timeout", () => {
          assert.equal(channel.state, "errored")
          done()
        })

        helpers.receiveTimeout()
      })

      it("triggers receive('timeout') callback after ok response", function(){
        const spyTimeout = sinon.spy()

        joinPush.receive("timeout", spyTimeout)

        helpers.receiveTimeout()

        assert.ok(spyTimeout.calledOnce)
      })

      it("does not trigger other receive callbacks after timeout response", function(done){
        const spyOk = sinon.spy()
        const spyError = sinon.spy()
        sinon.stub(channel.rejoinTimer, "scheduleTimeout").callsFake(() => true)

        channel.test = true
        joinPush
          .receive("ok", spyOk)
          .receive("error", spyError)
          .receive("timeout", () => {
            assert.ok(!spyOk.called)
            assert.ok(!spyError.called)
            done()
          })

        helpers.receiveTimeout()
        helpers.receiveOk()
      })

      it("schedules rejoinTimer timeout", function(){
        assert.ok(channel.rejoinTimer)

        const spy = sinon.spy(channel.rejoinTimer, "scheduleTimeout")

        helpers.receiveTimeout()

        assert.ok(spy.called) // TODO why called multiple times?
      })
    })

    describe("receives 'error'", function(){
      beforeEach(function(){
        response = {chan: "fail"}
      })

      it("triggers receive('error') callback after error response", function(){
        const spyError = sinon.spy()

        assert.equal(channel.state, "joining")
        joinPush.receive("error", spyError)

        helpers.receiveError()
        joinPush.trigger("error", {})

        assert.equal(spyError.callCount, 1)
      })

      it("triggers receive('error') callback if error response already received", function(){
        const spyError = sinon.spy()

        helpers.receiveError()

        joinPush.receive("error", spyError)

        assert.ok(spyError.calledOnce)
      })

      it("does not trigger other receive callbacks after error response", function(){
        const spyOk = sinon.spy()
        const spyError = sinon.spy()
        const spyTimeout = sinon.spy()

        joinPush
          .receive("ok", spyOk)
          .receive("error", () => {
            spyError()
            channel.leave()
          })
          .receive("timeout", spyTimeout)

        helpers.receiveError()
        clock.tick(channel.timeout * 2) // attempt timeout

        assert.ok(spyError.calledOnce)
        assert.ok(!spyOk.called)
        assert.ok(!spyTimeout.called)
      })

      it("clears timeoutTimer", function(){
        assert.ok(joinPush.timeoutTimer)

        helpers.receiveError()

        assert.equal(joinPush.timeoutTimer, null)
      })

      it("sets receivedResp with error trigger after binding", function(done){
        assert.equal(joinPush.receivedResp, null)

        joinPush.receive("error", resp => {
          assert.deepEqual(resp, response)
          done()
        })

        helpers.receiveError()
      })

      it("sets receivedResp with error trigger before binding", function(done){
        assert.equal(joinPush.receivedResp, null)

        helpers.receiveError()
        joinPush.receive("error", resp => {
          assert.deepEqual(resp, response)
          done()
        })
      })

      it("does not set channel state to joined", function(){
        helpers.receiveError()

        assert.equal(channel.state, "errored")
      })

      it("does not trigger channel's buffered pushEvents", function(){
        const pushEvent = {send: () => {}}
        const spy = sinon.spy(pushEvent, "send")

        channel.pushBuffer.push(pushEvent)

        helpers.receiveError()

        assert.ok(!spy.called)
        assert.equal(channel.pushBuffer.length, 1)
      })
    })
  })

  describe("onError", function(){
    let clock, joinPush

    beforeEach(function(){
      clock = sinon.useFakeTimers()

      socket = new Socket("/socket", {timeout: defaultTimeout})
      sinon.stub(socket, "isConnected").callsFake(() => true)
      sinon.stub(socket, "push").callsFake(() => true)

      channel = socket.channel("topic", {one: "two"})

      joinPush = channel.joinPush

      channel.join()
      joinPush.trigger("ok", {})
    })

    afterEach(function(){
      clock.restore()
    })

    it("sets state to 'errored'", function(){
      assert.notEqual(channel.state, "errored")

      channel.trigger("phx_error")

      assert.equal(channel.state, "errored")
    })

    it("does not trigger redundant errors during backoff", function(){
      const spy = sinon.stub(joinPush, "send")

      assert.equal(spy.callCount, 0)

      channel.trigger("phx_error")

      clock.tick(1000)
      assert.equal(spy.callCount, 1)

      joinPush.trigger("error", {})

      clock.tick(10000)
      assert.equal(spy.callCount, 1)
    })

    it("does not rejoin if channel leaving", function(){
      channel.state = "leaving"

      const spy = sinon.stub(joinPush, "send")

      socket.onConnError({})

      clock.tick(1000)
      assert.equal(spy.callCount, 0)

      clock.tick(2000)
      assert.equal(spy.callCount, 0)

      assert.equal(channel.state, "leaving")
    })

    it("does not rejoin if channel closed", function(){
      channel.state = "closed"

      const spy = sinon.stub(joinPush, "send")

      socket.onConnError({})

      clock.tick(1000)
      assert.equal(spy.callCount, 0)

      clock.tick(2000)
      assert.equal(spy.callCount, 0)

      assert.equal(channel.state, "closed")
    })

    it("triggers additional callbacks after join", function(){
      const spy = sinon.spy()
      channel.onError(spy)
      joinPush.trigger("ok", {})

      assert.equal(channel.state, "joined")
      assert.equal(spy.callCount, 0)

      channel.trigger("phx_error")

      assert.equal(spy.callCount, 1)
    })
  })

  describe("onClose", function(){
    let clock, joinPush

    beforeEach(function(){
      clock = sinon.useFakeTimers()

      socket = new Socket("/socket", {timeout: defaultTimeout})
      sinon.stub(socket, "isConnected").callsFake(() => true)
      sinon.stub(socket, "push").callsFake(() => true)

      channel = socket.channel("topic", {one: "two"})

      joinPush = channel.joinPush

      channel.join()
    })

    afterEach(function(){
      clock.restore()
    })

    it("sets state to 'closed'", function(){
      assert.notEqual(channel.state, "closed")

      channel.trigger("phx_close")

      assert.equal(channel.state, "closed")
    })

    it("does not rejoin", function(){
      const spy = sinon.stub(joinPush, "send")

      channel.trigger("phx_close")

      clock.tick(1000)
      assert.equal(spy.callCount, 0)

      clock.tick(2000)
      assert.equal(spy.callCount, 0)
    })

    it("triggers additional callbacks", function(){
      const spy = sinon.spy()
      channel.onClose(spy)

      assert.equal(spy.callCount, 0)

      channel.trigger("phx_close")

      assert.equal(spy.callCount, 1)
    })

    it("removes channel from socket", function(){
      assert.equal(socket.channels.length, 1)
      assert.deepEqual(socket.channels[0], channel)

      channel.trigger("phx_close")

      assert.equal(socket.channels.length, 0)
    })
  })

  describe("onMessage", function(){
    it("returns payload by default", function(){
      socket = new Socket("/socket")
      channel = socket.channel("topic", {one: "two"})
      sinon.stub(socket, "makeRef").callsFake(() => defaultRef)
      const payload = channel.onMessage("event", {one: "two"}, defaultRef)

      assert.deepEqual(payload, {one: "two"})
    })
  })

  describe("canPush", function(){
    beforeEach(function(){
      socket = new Socket("/socket")

      channel = socket.channel("topic", {one: "two"})
    })

    it("returns true when socket connected and channel joined", function(){
      sinon.stub(socket, "isConnected").returns(true)
      channel.state = "joined"

      assert.ok(channel.canPush())
    })

    it("otherwise returns false", function(){
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

  describe("on", function(){
    beforeEach(function(){
      socket = new Socket("/socket")
      sinon.stub(socket, "makeRef").callsFake(() => defaultRef)

      channel = socket.channel("topic", {one: "two"})
    })

    it("sets up callback for event", function(){
      const spy = sinon.spy()

      channel.trigger("event", {}, defaultRef)
      assert.ok(!spy.called)

      channel.on("event", spy)

      channel.trigger("event", {}, defaultRef)

      assert.ok(spy.called)
    })

    it("other event callbacks are ignored", function(){
      const spy = sinon.spy()
      const ignoredSpy = sinon.spy()

      channel.trigger("event", {}, defaultRef)

      assert.ok(!ignoredSpy.called)

      channel.on("event", spy)

      channel.trigger("event", {}, defaultRef)

      assert.ok(!ignoredSpy.called)
    })

    it("generates unique refs for callbacks", function(){
      const ref1 = channel.on("event1", () => 0)
      const ref2 = channel.on("event2", () => 0)
      assert.equal(ref1 + 1, ref2)
    })

    it("calls all callbacks for event if they modified during event processing", function(){
      const spy = sinon.spy()

      const ref = channel.on("event", () => {
        channel.off("event", ref)
      })
      channel.on("event", spy)

      channel.trigger("event", {}, defaultRef)

      assert.ok(spy.called)
    })
  })

  describe("off", function(){
    beforeEach(function(){
      socket = new Socket("/socket")
      sinon.stub(socket, "makeRef").callsFake(() => defaultRef)

      channel = socket.channel("topic", {one: "two"})
    })

    it("removes all callbacks for event", function(){
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

    it("removes callback by its ref", function(){
      const spy1 = sinon.spy()
      const spy2 = sinon.spy()

      const ref1 = channel.on("event", spy1)
      const _ref2 = channel.on("event", spy2)

      channel.off("event", ref1)
      channel.trigger("event", {}, defaultRef)

      assert.ok(!spy1.called)
      assert.ok(spy2.called)
    })
  })

  describe("push", function(){
    let clock, joinPush
    let socketSpy

    let pushParams = (channel) => {
      return ({
        topic: "topic",
        event: "event",
        payload: {foo: "bar"},
        join_ref: channel.joinRef(),
        ref: defaultRef
      })
    }

    beforeEach(function(){
      clock = sinon.useFakeTimers()

      socket = new Socket("/socket", {timeout: defaultTimeout})
      sinon.stub(socket, "makeRef").callsFake(() => defaultRef)
      sinon.stub(socket, "isConnected").callsFake(() => true)
      socketSpy = sinon.stub(socket, "push")

      channel = socket.channel("topic", {one: "two"})
    })

    afterEach(function(){
      clock.restore()
    })

    it("sends push event when successfully joined", function(){
      channel.join().trigger("ok", {})
      channel.push("event", {foo: "bar"})

      assert.ok(socketSpy.calledWith(pushParams(channel)))
    })

    it("enqueues push event to be sent once join has succeeded", function(){
      joinPush = channel.join()
      channel.push("event", {foo: "bar"})

      assert.ok(!socketSpy.calledWith(pushParams(channel)))

      clock.tick(channel.timeout / 2)
      joinPush.trigger("ok", {})

      assert.ok(socketSpy.calledWith(pushParams(channel)))
    })

    it("does not push if channel join times out", function(){
      joinPush = channel.join()
      channel.push("event", {foo: "bar"})

      assert.ok(!socketSpy.calledWith(pushParams(channel)))

      clock.tick(channel.timeout * 2)
      joinPush.trigger("ok", {})

      assert.ok(!socketSpy.calledWith(pushParams(channel)))
    })

    it("uses channel timeout by default", function(){
      const timeoutSpy = sinon.spy()
      channel.join().trigger("ok", {})

      channel.push("event", {foo: "bar"})
        .receive("timeout", timeoutSpy)

      clock.tick(channel.timeout / 2)
      assert.ok(!timeoutSpy.called)

      clock.tick(channel.timeout)
      assert.ok(timeoutSpy.called)
    })

    it("accepts timeout arg", function(){
      const timeoutSpy = sinon.spy()
      channel.join().trigger("ok", {})

      channel.push("event", {foo: "bar"}, channel.timeout * 2)
        .receive("timeout", timeoutSpy)

      clock.tick(channel.timeout)
      assert.ok(!timeoutSpy.called)

      clock.tick(channel.timeout * 2)
      assert.ok(timeoutSpy.called)
    })

    it("does not time out after receiving 'ok'", function(){
      channel.join().trigger("ok", {})
      const timeoutSpy = sinon.spy()
      const push = channel.push("event", {foo: "bar"})
      push.receive("timeout", timeoutSpy)

      clock.tick(push.timeout / 2)
      assert.ok(!timeoutSpy.called)

      push.trigger("ok", {})

      clock.tick(push.timeout)
      assert.ok(!timeoutSpy.called)
    })

    it("throws if channel has not been joined", function(){
      assert.throws(() => channel.push("event", {}), /^Error: tried to push.*before joining/)
    })
  })

  describe("leave", function(){
    let clock
    let socketSpy

    beforeEach(function(){
      clock = sinon.useFakeTimers()

      socket = new Socket("/socket", {timeout: defaultTimeout})
      sinon.stub(socket, "isConnected").callsFake(() => true)
      socketSpy = sinon.stub(socket, "push")

      channel = socket.channel("topic", {one: "two"})
      channel.join().trigger("ok", {})
    })

    afterEach(function(){
      clock.restore()
    })

    it("unsubscribes from server events", function(){
      sinon.stub(socket, "makeRef").callsFake(() => defaultRef)
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

    it("closes channel on 'ok' from server", function(){
      const anotherChannel = socket.channel("another", {three: "four"})
      assert.equal(socket.channels.length, 2)

      channel.leave().trigger("ok", {})

      assert.equal(socket.channels.length, 1)
      assert.deepEqual(socket.channels[0], anotherChannel)
    })

    it("sets state to closed on 'ok' event", function(){
      assert.notEqual(channel.state, "closed")

      channel.leave().trigger("ok", {})

      assert.equal(channel.state, "closed")
    })

    // TODO - the following tests are skipped until Channel.leave
    // behavior can be fixed; currently, 'ok' is triggered immediately
    // within Channel.leave so timeout callbacks are never reached
    //
    it.skip("sets state to leaving initially", function(){
      assert.notEqual(channel.state, "leaving")

      channel.leave()

      assert.equal(channel.state, "leaving")
    })

    it.skip("closes channel on 'timeout'", function(){
      channel.leave()

      clock.tick(channel.timeout)

      assert.equal(channel.state, "closed")
    })

    it.skip("accepts timeout arg", function(){
      channel.leave(channel.timeout * 2)

      clock.tick(channel.timeout)

      assert.equal(channel.state, "leaving")

      clock.tick(channel.timeout * 2)

      assert.equal(channel.state, "closed")
    })
  })

})
