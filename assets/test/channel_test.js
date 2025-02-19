import {jest} from "@jest/globals"
import {Channel, Socket} from "../js/phoenix"

let channel, socket

const defaultRef = 1
const defaultTimeout = 10000

class WSMock {
  constructor(url, protocols){
    this.url = url
    this.protocols = protocols
  }
  close(){}
  send(){}
}

describe("with transport", function (){
  beforeAll(function (){
    global.WebSocket = WSMock
  })

  afterAll(function (){
    global.WebSocket = null
  })

  describe("constructor", function (){
    beforeEach(function (){
      socket = new Socket("/", {timeout: 1234})
    })

    it("sets defaults", function (){
      channel = new Channel("topic", {one: "two"}, socket)

      expect(channel.state).toBe("closed")
      expect(channel.topic).toBe("topic")
      expect(channel.params()).toEqual({one: "two"})
      expect(channel.socket).toBe(socket)
      expect(channel.timeout).toBe(1234)
      expect(channel.joinedOnce).toBe(false)
      expect(channel.joinPush).toBeTruthy()
      expect(channel.pushBuffer).toEqual([])
    })

    it("sets up joinPush object with literal params", function (){
      channel = new Channel("topic", {one: "two"}, socket)
      const joinPush = channel.joinPush

      expect(joinPush.channel).toBe(channel)
      expect(joinPush.payload()).toEqual({one: "two"})
      expect(joinPush.event).toBe("phx_join")
      expect(joinPush.timeout).toBe(1234)
    })

    it("sets up joinPush object with closure params", function (){
      channel = new Channel("topic", () => ({one: "two"}), socket)
      const joinPush = channel.joinPush

      expect(joinPush.channel).toBe(channel)
      expect(joinPush.payload()).toEqual({one: "two"})
      expect(joinPush.event).toBe("phx_join")
      expect(joinPush.timeout).toBe(1234)
    })

    it("sets subprotocols when authToken is provided", function (){
      const authToken = "1234"
      const socket = new Socket("/socket", {authToken})
      
      socket.connect()
      expect(socket.conn.protocols).toEqual(["phoenix", "base64url.bearer.phx.MTIzNA"])
    })
  })

  describe("updating join params", function (){
    it("can update the join params", function (){
      let counter = 0
      let params = () => ({value: counter})
      socket = {timeout: 1234, onError: function (){}, onOpen: function (){}}

      channel = new Channel("topic", params, socket)
      const joinPush = channel.joinPush

      expect(joinPush.channel).toBe(channel)
      expect(joinPush.payload()).toEqual({value: 0})
      expect(joinPush.event).toBe("phx_join")
      expect(joinPush.timeout).toBe(1234)

      counter++

      expect(joinPush.channel).toBe(channel)
      expect(joinPush.payload()).toEqual({value: 1})
      expect(channel.params()).toEqual({value: 1})
      expect(joinPush.event).toBe("phx_join")
      expect(joinPush.timeout).toBe(1234)
    })
  })

  describe("join", function (){
    beforeEach(function (){
      socket = new Socket("/socket", {timeout: defaultTimeout})

      channel = socket.channel("topic", {one: "two"})
    })

    it("sets state to joining", function (){
      channel.join()

      expect(channel.state).toBe("joining")
    })

    it("sets joinedOnce to true", function (){
      expect(channel.joinedOnce).toBe(false)

      channel.join()

      expect(channel.joinedOnce).toBe(true)
    })

    it("throws if attempting to join multiple times", function (){
      channel.join()

      expect(() => channel.join()).toThrow(/^tried to join multiple times/)
    })

    it("triggers socket push with channel params", function (){
      jest.spyOn(socket, "makeRef").mockReturnValue(defaultRef)
      const spy = jest.spyOn(socket, "push")

      channel.join()

      expect(spy).toHaveBeenCalledTimes(1)
      expect(spy).toHaveBeenCalledWith({
        topic: "topic",
        event: "phx_join",
        payload: {one: "two"},
        ref: defaultRef,
        join_ref: channel.joinRef(),
      })
    })

    it("can set timeout on joinPush", function (){
      const newTimeout = 2000
      const joinPush = channel.joinPush

      expect(joinPush.timeout).toBe(defaultTimeout)

      channel.join(newTimeout)

      expect(joinPush.timeout).toBe(newTimeout)
    })

    it("leaves existing duplicate topic on new join", function (done){
      channel.join().receive("ok", () => {
        let newChannel = socket.channel("topic")
        expect(channel.isJoined()).toBe(true)
        newChannel.join()
        expect(channel.isJoined()).toBe(false)
        done()
      })

      channel.joinPush.trigger("ok", {})
    })

    describe("timeout behavior", function (){
      let joinPush

      const helpers = {
        receiveSocketOpen(){
          jest.spyOn(socket, "isConnected").mockReturnValue(true)
          socket.onConnOpen()
        },
      }

      beforeEach(function (){
        jest.useFakeTimers()
        joinPush = channel.joinPush
      })

      afterEach(function (){
        jest.useRealTimers()
      })

      it("succeeds before timeout", function (){
        const spy = jest.spyOn(socket, "push")
        const timeout = joinPush.timeout

        socket.connect()
        helpers.receiveSocketOpen()

        channel.join()
        expect(spy).toHaveBeenCalledTimes(1)

        expect(channel.timeout).toBe(10000)
        jest.advanceTimersByTime(100)

        joinPush.trigger("ok", {})

        expect(channel.state).toBe("joined")

        jest.advanceTimersByTime(timeout)
        expect(spy).toHaveBeenCalledTimes(1)
      })

      it("retries with backoff after timeout", function (){
        const spy = jest.spyOn(socket, "push")
        const timeoutSpy = jest.fn()
        const timeout = joinPush.timeout

        socket.connect()
        helpers.receiveSocketOpen()

        channel.join().receive("timeout", timeoutSpy)

        expect(spy).toHaveBeenCalledTimes(1)
        expect(timeoutSpy).toHaveBeenCalledTimes(0)

        jest.advanceTimersByTime(timeout)
        expect(spy).toHaveBeenCalledTimes(2) // leave pushed to server
        expect(timeoutSpy).toHaveBeenCalledTimes(1)

        jest.advanceTimersByTime(timeout + 1000)
        expect(spy).toHaveBeenCalledTimes(4) // leave + rejoin
        expect(timeoutSpy).toHaveBeenCalledTimes(2)

        jest.advanceTimersByTime(10000)
        joinPush.trigger("ok", {})
        expect(spy).toHaveBeenCalledTimes(6)
        expect(channel.state).toBe("joined")
      })

      it("with socket and join delay", function (){
        const spy = jest.spyOn(socket, "push")
        jest.useFakeTimers()
        const joinPush = channel.joinPush

        channel.join()
        expect(spy).toHaveBeenCalledTimes(1)

        // open socket after delay
        jest.advanceTimersByTime(9000)

        expect(spy).toHaveBeenCalledTimes(1)

        // join request returns between timeouts
        jest.advanceTimersByTime(1000)
        socket.connect()

        expect(channel.state).toBe("errored")

        helpers.receiveSocketOpen()
        joinPush.trigger("ok", {})

        // join request succeeds after delay
        jest.advanceTimersByTime(1000)

        expect(channel.state).toBe("joined")

        expect(spy).toHaveBeenCalledTimes(3) // leave pushed to server
      })

      it("with socket delay only", function (){
        jest.useFakeTimers()
        const joinPush = channel.joinPush

        channel.join()

        expect(channel.state).toBe("joining")

        // connect socket after delay
        jest.advanceTimersByTime(6000)
        socket.connect()

        // open socket after delay
        jest.advanceTimersByTime(5000)
        helpers.receiveSocketOpen()
        joinPush.trigger("ok", {})

        joinPush.trigger("ok", {})
        expect(channel.state).toBe("joined")
      })
    })
  })

  describe("joinPush", function (){
    let joinPush
    let response

    const helpers = {
      receiveOk(){
        jest.advanceTimersByTime(joinPush.timeout / 2) // before timeout
        return joinPush.channel.trigger("phx_reply", {status: "ok", response: response}, joinPush.ref, joinPush.ref)
        // return joinPush.trigger("ok", response)
      },

      receiveTimeout(){
        jest.advanceTimersByTime(joinPush.timeout * 2) // after timeout
      },

      receiveError(){
        jest.advanceTimersByTime(joinPush.timeout / 2) // before timeout
        return joinPush.trigger("error", response)
      },

      getBindings(event){
        return channel.bindings.filter(bind => bind.event === event)
      },
    }

    beforeEach(function (){
      jest.useFakeTimers()

      socket = new Socket("/socket", {timeout: defaultTimeout})
      jest.spyOn(socket, "isConnected").mockReturnValue(true)
      jest.spyOn(socket, "push").mockReturnValue(true)

      channel = socket.channel("topic", {one: "two"})
      joinPush = channel.joinPush

      channel.join()
    })

    afterEach(function (){
      jest.useRealTimers()
    })

    describe("receives 'ok'", function (){
      beforeEach(function (){
        response = {chan: "reply"}
      })

      it("sets channel state to joined", function (){
        expect(channel.state).not.toBe("joined")

        helpers.receiveOk()

        expect(channel.state).toBe("joined")
      })

      it("triggers receive('ok') callback after ok response", function (){
        const spyOk = jest.fn()

        joinPush.receive("ok", spyOk)

        helpers.receiveOk()

        expect(spyOk).toHaveBeenCalledTimes(1)
      })

      it("triggers receive('ok') callback if ok response already received", function (){
        const spyOk = jest.fn()

        helpers.receiveOk()

        joinPush.receive("ok", spyOk)

        expect(spyOk).toHaveBeenCalledTimes(1)
      })

      it("does not trigger other receive callbacks after ok response", function (){
        const spyError = jest.fn()
        const spyTimeout = jest.fn()

        joinPush.receive("error", spyError).receive("timeout", spyTimeout)

        helpers.receiveOk()
        jest.advanceTimersByTime(channel.timeout * 2) // attempt timeout

        expect(spyError).not.toHaveBeenCalled()
        expect(spyTimeout).not.toHaveBeenCalled()
      })

      it("clears timeoutTimer", function (){
        expect(joinPush.timeoutTimer).toBeTruthy()

        helpers.receiveOk()

        expect(joinPush.timeoutTimer).toBeNull()
      })

      it("sets receivedResp", function (){
        expect(joinPush.receivedResp).toBeNull()

        helpers.receiveOk()

        expect(joinPush.receivedResp).toEqual({status: "ok", response})
      })

      it("removes channel bindings", function (){
        let bindings = helpers.getBindings("chan_reply_3")
        expect(bindings.length).toBe(1)

        helpers.receiveOk()

        bindings = helpers.getBindings("chan_reply_3")
        expect(bindings.length).toBe(0)
      })

      it("resets channel rejoinTimer", function (){
        expect(channel.rejoinTimer).toBeTruthy()

        const spy = jest.spyOn(channel.rejoinTimer, "reset")

        helpers.receiveOk()

        expect(spy).toHaveBeenCalledTimes(1)
      })

      it("sends and empties channel's buffered pushEvents", function (done){
        const pushEvent = {send(){}}
        const spy = jest.spyOn(pushEvent, "send")

        channel.pushBuffer.push(pushEvent)

        expect(channel.state).toBe("joining")
        joinPush.receive("ok", () => {
          expect(spy).toHaveBeenCalledTimes(1)
          expect(channel.pushBuffer.length).toBe(0)
          done()
        })
        helpers.receiveOk()
      })
    })

    describe("receives 'timeout'", function (){
      it("sets channel state to errored", function (done){
        joinPush.receive("timeout", () => {
          expect(channel.state).toBe("errored")
          done()
        })

        helpers.receiveTimeout()
      })

      it("triggers receive('timeout') callback after ok response", function (){
        const spyTimeout = jest.fn()

        joinPush.receive("timeout", spyTimeout)

        helpers.receiveTimeout()

        expect(spyTimeout).toHaveBeenCalledTimes(1)
      })

      it("does not trigger other receive callbacks after timeout response", function (done){
        const spyOk = jest.fn()
        const spyError = jest.fn()
        jest.spyOn(channel.rejoinTimer, "scheduleTimeout").mockReturnValue(true)

        channel.test = true
        joinPush.receive("ok", spyOk).receive("error", spyError).receive("timeout", () => {
          expect(spyOk).not.toHaveBeenCalled()
          expect(spyError).not.toHaveBeenCalled()
          done()
        })

        helpers.receiveTimeout()
        helpers.receiveOk()
      })

      it("schedules rejoinTimer timeout", function (){
        expect(channel.rejoinTimer).toBeTruthy()

        const spy = jest.spyOn(channel.rejoinTimer, "scheduleTimeout")

        helpers.receiveTimeout()

        expect(spy).toHaveBeenCalled() // TODO why called multiple times?
      })
    })

    describe("receives 'error'", function (){
      beforeEach(function (){
        response = {chan: "fail"}
      })

      it("triggers receive('error') callback after error response", function (){
        const spyError = jest.fn()

        expect(channel.state).toBe("joining")
        joinPush.receive("error", spyError)

        helpers.receiveError()
        joinPush.trigger("error", {})

        expect(spyError).toHaveBeenCalledTimes(1)
      })

      it("triggers receive('error') callback if error response already received", function (){
        const spyError = jest.fn()

        helpers.receiveError()

        joinPush.receive("error", spyError)

        expect(spyError).toHaveBeenCalledTimes(1)
      })

      it("does not trigger other receive callbacks after error response", function (){
        const spyOk = jest.fn()
        const spyError = jest.fn()
        const spyTimeout = jest.fn()

        joinPush.receive("ok", spyOk).receive("error", () => {
          spyError()
          channel.leave()
        }).receive("timeout", spyTimeout)

        helpers.receiveError()
        jest.advanceTimersByTime(channel.timeout * 2) // attempt timeout

        expect(spyError).toHaveBeenCalledTimes(1)
        expect(spyOk).not.toHaveBeenCalled()
        expect(spyTimeout).not.toHaveBeenCalled()
      })

      it("clears timeoutTimer", function (){
        expect(joinPush.timeoutTimer).toBeTruthy()

        helpers.receiveError()

        expect(joinPush.timeoutTimer).toBeNull()
      })

      it("sets receivedResp with error trigger after binding", function (done){
        expect(joinPush.receivedResp).toBeNull()

        joinPush.receive("error", resp => {
          expect(resp).toEqual(response)
          done()
        })

        helpers.receiveError()
      })

      it("sets receivedResp with error trigger before binding", function (done){
        expect(joinPush.receivedResp).toBeNull()

        helpers.receiveError()
        joinPush.receive("error", resp => {
          expect(resp).toEqual(response)
          done()
        })
      })

      it("does not set channel state to joined", function (){
        helpers.receiveError()

        expect(channel.state).toBe("errored")
      })

      it("does not trigger channel's buffered pushEvents", function (){
        const pushEvent = {send: () => {}}
        const spy = jest.spyOn(pushEvent, "send")

        channel.pushBuffer.push(pushEvent)

        helpers.receiveError()

        expect(spy).not.toHaveBeenCalled()
        expect(channel.pushBuffer.length).toBe(1)
      })
    })
  })

  describe("onError", function (){
    let joinPush

    beforeEach(function (){
      jest.useFakeTimers()

      socket = new Socket("/socket", {timeout: defaultTimeout})
      jest.spyOn(socket, "isConnected").mockReturnValue(true)
      jest.spyOn(socket, "push").mockReturnValue(true)

      channel = socket.channel("topic", {one: "two"})

      joinPush = channel.joinPush

      channel.join()
      joinPush.trigger("ok", {})
    })

    afterEach(function (){
      jest.useRealTimers()
    })

    it("sets state to 'errored'", function (){
      expect(channel.state).not.toBe("errored")

      channel.trigger("phx_error")

      expect(channel.state).toBe("errored")
    })

    it("does not trigger redundant errors during backoff", function (){
      const spy = jest.spyOn(joinPush, "send").mockImplementation(() => {})

      expect(spy).toHaveBeenCalledTimes(0)

      channel.trigger("phx_error")

      jest.advanceTimersByTime(1000)
      expect(spy).toHaveBeenCalledTimes(1)

      joinPush.trigger("error", {})

      jest.advanceTimersByTime(10000)
      expect(spy).toHaveBeenCalledTimes(1)
    })

    it("does not rejoin if channel leaving", function (){
      channel.state = "leaving"

      const spy = jest.spyOn(joinPush, "send")

      socket.onConnError({})

      jest.advanceTimersByTime(1000)
      expect(spy).toHaveBeenCalledTimes(0)

      jest.advanceTimersByTime(2000)
      expect(spy).toHaveBeenCalledTimes(0)

      expect(channel.state).toBe("leaving")
    })

    it("does not rejoin if channel closed", function (){
      channel.state = "closed"

      const spy = jest.spyOn(joinPush, "send")

      socket.onConnError({})

      jest.advanceTimersByTime(1000)
      expect(spy).toHaveBeenCalledTimes(0)

      jest.advanceTimersByTime(2000)
      expect(spy).toHaveBeenCalledTimes(0)

      expect(channel.state).toBe("closed")
    })

    it("triggers additional callbacks after join", function (){
      const spy = jest.fn()
      channel.onError(spy)
      joinPush.trigger("ok", {})

      expect(channel.state).toBe("joined")
      expect(spy).toHaveBeenCalledTimes(0)

      channel.trigger("phx_error")

      expect(spy).toHaveBeenCalledTimes(1)
    })
  })

  describe("onClose", function (){
    let joinPush

    beforeEach(function (){
      jest.useFakeTimers()

      socket = new Socket("/socket", {timeout: defaultTimeout})
      jest.spyOn(socket, "isConnected").mockReturnValue(true)
      jest.spyOn(socket, "push").mockReturnValue(true)

      channel = socket.channel("topic", {one: "two"})

      joinPush = channel.joinPush

      channel.join()
    })

    afterEach(function (){
      jest.useRealTimers()
    })

    it("sets state to 'closed'", function (){
      expect(channel.state).not.toBe("closed")

      channel.trigger("phx_close")

      expect(channel.state).toBe("closed")
    })

    it("does not rejoin", function (){
      const spy = jest.spyOn(joinPush, "send")

      channel.trigger("phx_close")

      jest.advanceTimersByTime(1000)
      expect(spy).toHaveBeenCalledTimes(0)

      jest.advanceTimersByTime(2000)
      expect(spy).toHaveBeenCalledTimes(0)
    })

    it("triggers additional callbacks", function (){
      const spy = jest.fn()
      channel.onClose(spy)

      expect(spy).toHaveBeenCalledTimes(0)

      channel.trigger("phx_close")

      expect(spy).toHaveBeenCalledTimes(1)
    })

    it("removes channel from socket", function (){
      expect(socket.channels.length).toBe(1)
      expect(socket.channels[0]).toBe(channel)

      channel.trigger("phx_close")

      expect(socket.channels.length).toBe(0)
    })
  })

  describe("onMessage", function (){
    it("returns payload by default", function (){
      socket = new Socket("/socket")
      channel = socket.channel("topic", {one: "two"})
      jest.spyOn(socket, "makeRef").mockReturnValue(defaultRef)
      const payload = channel.onMessage("event", {one: "two"}, defaultRef)

      expect(payload).toEqual({one: "two"})
    })
  })

  describe("canPush", function (){
    beforeEach(function (){
      socket = new Socket("/socket")

      channel = socket.channel("topic", {one: "two"})
    })

    it("returns true when socket connected and channel joined", function (){
      jest.spyOn(socket, "isConnected").mockReturnValue(true)
      channel.state = "joined"

      expect(channel.canPush()).toBe(true)
    })

    it("otherwise returns false", function (){
      const isConnectedStub = jest.spyOn(socket, "isConnected")

      isConnectedStub.mockReturnValue(false)
      channel.state = "joined"

      expect(channel.canPush()).toBe(false)

      isConnectedStub.mockReturnValue(true)
      channel.state = "joining"

      expect(channel.canPush()).toBe(false)

      isConnectedStub.mockReturnValue(false)
      channel.state = "joining"

      expect(channel.canPush()).toBe(false)
    })
  })

  describe("on", function (){
    beforeEach(function (){
      socket = new Socket("/socket")
      jest.spyOn(socket, "makeRef").mockReturnValue(defaultRef)

      channel = socket.channel("topic", {one: "two"})
    })

    it("sets up callback for event", function (){
      const spy = jest.fn()

      channel.trigger("event", {}, defaultRef)
      expect(spy).not.toHaveBeenCalled()

      channel.on("event", spy)

      channel.trigger("event", {}, defaultRef)

      expect(spy).toHaveBeenCalled()
    })

    it("other event callbacks are ignored", function (){
      const spy = jest.fn()
      const ignoredSpy = jest.fn()

      channel.trigger("event", {}, defaultRef)

      expect(ignoredSpy).not.toHaveBeenCalled()

      channel.on("event", spy)

      channel.trigger("event", {}, defaultRef)

      expect(ignoredSpy).not.toHaveBeenCalled()
    })

    it("generates unique refs for callbacks", function (){
      const ref1 = channel.on("event1", () => 0)
      const ref2 = channel.on("event2", () => 0)
      expect(ref1 + 1).toBe(ref2)
    })

    it("calls all callbacks for event if they modified during event processing", function (){
      const spy = jest.fn()

      const ref = channel.on("event", () => {
        channel.off("event", ref)
      })
      channel.on("event", spy)

      channel.trigger("event", {}, defaultRef)

      expect(spy).toHaveBeenCalled()
    })
  })

  describe("off", function (){
    beforeEach(function (){
      socket = new Socket("/socket")
      jest.spyOn(socket, "makeRef").mockReturnValue(defaultRef)

      channel = socket.channel("topic", {one: "two"})
    })

    it("removes all callbacks for event", function (){
      const spy1 = jest.fn()
      const spy2 = jest.fn()
      const spy3 = jest.fn()

      channel.on("event", spy1)
      channel.on("event", spy2)
      channel.on("other", spy3)

      channel.off("event")

      channel.trigger("event", {}, defaultRef)
      channel.trigger("other", {}, defaultRef)

      expect(spy1).not.toHaveBeenCalled()
      expect(spy2).not.toHaveBeenCalled()
      expect(spy3).toHaveBeenCalled()
    })

    it("removes callback by its ref", function (){
      const spy1 = jest.fn()
      const spy2 = jest.fn()

      const ref1 = channel.on("event", spy1)
      const _ref2 = channel.on("event", spy2)

      channel.off("event", ref1)
      channel.trigger("event", {}, defaultRef)

      expect(spy1).not.toHaveBeenCalled()
      expect(spy2).toHaveBeenCalled()
    })
  })

  describe("push", function (){
    let joinPush
    let socketSpy

    const pushParams = (channel) => {
      return {
        topic: "topic",
        event: "event",
        payload: {foo: "bar"},
        join_ref: channel.joinRef(),
        ref: defaultRef,
      }
    }

    beforeEach(function (){
      jest.useFakeTimers()

      socket = new Socket("/socket", {timeout: defaultTimeout})
      jest.spyOn(socket, "makeRef").mockReturnValue(defaultRef)
      jest.spyOn(socket, "isConnected").mockReturnValue(true)
      socketSpy = jest.spyOn(socket, "push").mockReturnValue(undefined)

      channel = socket.channel("topic", {one: "two"})
    })

    afterEach(function (){
      jest.useRealTimers()
    })

    it("sends push event when successfully joined", function (){
      channel.join().trigger("ok", {})
      channel.push("event", {foo: "bar"})

      expect(socketSpy).toHaveBeenCalledWith(pushParams(channel))
    })

    it("enqueues push event to be sent once join has succeeded", function (){
      joinPush = channel.join()
      channel.push("event", {foo: "bar"})

      expect(socketSpy).not.toHaveBeenCalledWith(pushParams(channel))

      jest.advanceTimersByTime(channel.timeout / 2)
      joinPush.trigger("ok", {})

      expect(socketSpy).toHaveBeenCalledWith(pushParams(channel))
    })

    it("does not push if channel join times out", function (){
      joinPush = channel.join()
      channel.push("event", {foo: "bar"})

      expect(socketSpy).not.toHaveBeenCalledWith(pushParams(channel))

      jest.advanceTimersByTime(channel.timeout * 2)
      joinPush.trigger("ok", {})

      expect(socketSpy).not.toHaveBeenCalledWith(pushParams(channel))
    })

    it("uses channel timeout by default", function (){
      const timeoutSpy = jest.fn()
      channel.join().trigger("ok", {})

      channel.push("event", {foo: "bar"}).receive("timeout", timeoutSpy)

      jest.advanceTimersByTime(channel.timeout / 2)
      expect(timeoutSpy).not.toHaveBeenCalled()

      jest.advanceTimersByTime(channel.timeout)
      expect(timeoutSpy).toHaveBeenCalled()
    })

    it("accepts timeout arg", function (){
      const timeoutSpy = jest.fn()
      channel.join().trigger("ok", {})

      channel.push("event", {foo: "bar"}, channel.timeout * 2).receive("timeout", timeoutSpy)

      jest.advanceTimersByTime(channel.timeout)
      expect(timeoutSpy).not.toHaveBeenCalled()

      jest.advanceTimersByTime(channel.timeout * 2)
      expect(timeoutSpy).toHaveBeenCalled()
    })

    it("does not time out after receiving 'ok'", function (){
      channel.join().trigger("ok", {})
      const timeoutSpy = jest.fn()
      const push = channel.push("event", {foo: "bar"})
      push.receive("timeout", timeoutSpy)

      jest.advanceTimersByTime(push.timeout / 2)
      expect(timeoutSpy).not.toHaveBeenCalled()

      push.trigger("ok", {})

      jest.advanceTimersByTime(push.timeout)
      expect(timeoutSpy).not.toHaveBeenCalled()
    })

    it("throws if channel has not been joined", function (){
      expect(() => channel.push("event", {})).toThrow(/^tried to push.*before joining/)
    })
  })

  describe("leave", function (){
    let socketSpy

    beforeEach(function (){
      jest.useFakeTimers()

      socket = new Socket("/socket", {timeout: defaultTimeout})
      jest.spyOn(socket, "isConnected").mockReturnValue(true)
      socketSpy = jest.spyOn(socket, "push").mockReturnValue(undefined)

      channel = socket.channel("topic", {one: "two"})
      channel.join().trigger("ok", {})
    })

    afterEach(function (){
      jest.useRealTimers()
    })

    it("unsubscribes from server events", function (){
      jest.spyOn(socket, "makeRef").mockReturnValue(defaultRef)
      const joinRef = channel.joinRef()

      channel.leave()

      expect(socketSpy).toHaveBeenCalledWith({
        topic: "topic",
        event: "phx_leave",
        payload: {},
        ref: defaultRef,
        join_ref: joinRef,
      })
    })

    it("closes channel on 'ok' from server", function (){
      const anotherChannel = socket.channel("another", {three: "four"})
      expect(socket.channels.length).toBe(2)

      channel.leave().trigger("ok", {})

      expect(socket.channels.length).toBe(1)
      expect(socket.channels[0]).toBe(anotherChannel)
    })

    it("sets state to closed on 'ok' event", function (){
      expect(channel.state).not.toBe("closed")

      channel.leave().trigger("ok", {})

      expect(channel.state).toBe("closed")
    })

    // TODO - the following tests are skipped until Channel.leave
    // behavior can be fixed; currently, 'ok' is triggered immediately
    // within Channel.leave so timeout callbacks are never reached
    //
    it.skip("sets state to leaving initially", function (){
      expect(channel.state).not.toBe("leaving")

      channel.leave()

      expect(channel.state).toBe("leaving")
    })

    it.skip("closes channel on 'timeout'", function (){
      channel.leave()

      jest.advanceTimersByTime(channel.timeout)

      expect(channel.state).toBe("closed")
    })

    it.skip("accepts timeout arg", function (){
      channel.leave(channel.timeout * 2)

      jest.advanceTimersByTime(channel.timeout)

      expect(channel.state).toBe("leaving")

      jest.advanceTimersByTime(channel.timeout * 2)

      expect(channel.state).toBe("closed")
    })
  })
})
