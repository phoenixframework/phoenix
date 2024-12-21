import {closure} from "./utils"
import {CHANNEL_EVENTS, CHANNEL_STATES} from "./constants"

import Push from "./push"
import Timer from "./timer"

export default class Channel {
  constructor(topic, params = {}, socket) {
    this.state = CHANNEL_STATES.closed
    this.topic = topic
    this.params = closure(params)
    this.socket = socket
    this.bindings = new Map() // Efficient event management
    this.bindingRef = 0
    this.timeout = this.socket.timeout
    this.joinedOnce = false
    this.joinPush = new Push(this, CHANNEL_EVENTS.join, this.params, this.timeout)
    this.pushBuffer = []
    this.stateChangeRefs = []

    this.rejoinTimer = new Timer(
      () => {
        if (this.socket.isConnected()) this.rejoin()
      },
      this.socket.rejoinAfterMs
    )

    this.setupSocketListeners()
    this.setupJoinPush()
  }

  setupSocketListeners() {
    this.stateChangeRefs.push(this.socket.onError(() => this.rejoinTimer.reset()))
    this.stateChangeRefs.push(
      this.socket.onOpen(() => {
        this.rejoinTimer.reset()
        if (this.isErrored()) this.rejoin()
      })
    )
  }

  setupJoinPush() {
    this.joinPush
      .receive("ok", () => {
        this.state = CHANNEL_STATES.joined
        this.rejoinTimer.reset()
        this.pushBuffer.forEach((pushEvent) => pushEvent.send())
        this.pushBuffer = []
      })
      .receive("error", () => {
        this.state = CHANNEL_STATES.errored
        if (this.socket.isConnected()) this.rejoinTimer.scheduleTimeout()
      })
      .receive("timeout", () => this.handleJoinTimeout())
  }

  handleJoinTimeout() {
    if (this.socket.hasLogger()) {
      this.socket.log("channel", `timeout ${this.topic} (${this.joinRef()})`, this.joinPush.timeout)
    }
    const leavePush = new Push(this, CHANNEL_EVENTS.leave, closure({}), this.timeout)
    leavePush.send()
    this.state = CHANNEL_STATES.errored
    this.joinPush.reset()
    if (this.socket.isConnected()) this.rejoinTimer.scheduleTimeout()
  }

  join(timeout = this.timeout) {
    if (this.joinedOnce) {
      throw new Error("tried to join multiple times. 'join' can only be called a single time per channel instance")
    }
    this.timeout = timeout
    this.joinedOnce = true
    this.rejoin()
    return this.joinPush
  }

  on(event, callback) {
    const ref = this.bindingRef++
    if (!this.bindings.has(event)) {
      this.bindings.set(event, new Map())
    }
    this.bindings.get(event).set(ref, callback)
    return ref
  }

  off(event, ref) {
    if (!this.bindings.has(event)) return
    if (ref === undefined) {
      this.bindings.delete(event)
    } else {
      this.bindings.get(event)?.delete(ref)
      if (this.bindings.get(event)?.size === 0) {
        this.bindings.delete(event)
      }
    }
  }

  canPush() {
    return this.socket.isConnected() && this.isJoined()
  }

  push(event, payload = {}, timeout = this.timeout) {
    if (!this.joinedOnce) {
      throw new Error(`tried to push '${event}' to '${this.topic}' before joining. Use channel.join() before pushing events`)
    }
    const pushEvent = new Push(this, event, () => payload, timeout)
    if (this.canPush()) {
      pushEvent.send()
    } else {
      pushEvent.startTimeout()
      this.pushBuffer.push(pushEvent)
    }
    return pushEvent
  }

  leave(timeout = this.timeout) {
    this.rejoinTimer.reset()
    this.joinPush.cancelTimeout()

    this.state = CHANNEL_STATES.leaving
    const leavePush = new Push(this, CHANNEL_EVENTS.leave, closure({}), timeout)
    leavePush
      .receive("ok", () => this.handleLeave())
      .receive("timeout", () => this.handleLeave())
    leavePush.send()

    if (!this.canPush()) leavePush.trigger("ok", {})
    return leavePush
  }

  handleLeave() {
    if (this.socket.hasLogger()) {
      this.socket.log("channel", `leave ${this.topic}`)
    }
    this.trigger(CHANNEL_EVENTS.close, "leave")
  }

  trigger(event, payload, ref, joinRef) {
    const handledPayload = this.onMessage(event, payload, ref, joinRef)
    if (payload && !handledPayload) {
      throw new Error("channel onMessage callbacks must return the payload, modified or unmodified")
    }
    const eventBindings = this.bindings.get(event) || new Map()
    eventBindings.forEach((callback) => callback(handledPayload, ref, joinRef || this.joinRef()))
  }

  isClosed() {
    return this.state === CHANNEL_STATES.closed
  }
  isErrored() {
    return this.state === CHANNEL_STATES.errored
  }
  isJoined() {
    return this.state === CHANNEL_STATES.joined
  }
  isJoining() {
    return this.state === CHANNEL_STATES.joining
  }
  isLeaving() {
    return this.state === CHANNEL_STATES.leaving
  }
}
