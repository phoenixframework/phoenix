import {closure} from "./utils"
import {
  CHANNEL_EVENTS,
  CHANNEL_STATES,
} from "./constants"

import Push from "./push"
import Timer from "./timer"

/**
* @import Socket from "./socket"
* @import { ChannelState, Params, ChannelBindingCallback, ChannelOnMessage, ChannelFilterBindings, ChannelOnErrorCallback, ChannelBinding } from "./types"
*/

export default class Channel {
/**
 * @param {string} topic
 * @param {Params | (() => Params)} params
 * @param {Socket} socket
 */
  constructor(topic, params, socket){
    /** @type{ChannelState} */
    this.state = CHANNEL_STATES.closed
    /** @type{string} */
    this.topic = topic
    /** @type{() => Params} */
    this.params = closure(params || {})
    /** @type {Socket} */
    this.socket = socket
    /** @type{ChannelBinding[]} */
    this.bindings = []
    /** @type{number} */
    this.bindingRef = 0
    /** @type{number} */
    this.timeout = this.socket.timeout
    /** @type{boolean} */
    this.joinedOnce = false
    /** @type{Push} */
    this.joinPush = new Push(this, CHANNEL_EVENTS.join, this.params, this.timeout)
    /** @type{Push[]} */
    this.pushBuffer = []
    /** @type{string[]} */
    this.stateChangeRefs = []

    /** @type{Timer} */
    this.rejoinTimer = new Timer(() => {
      if(this.socket.isConnected()){ this.rejoin() }
    }, this.socket.rejoinAfterMs)
    this.stateChangeRefs.push(this.socket.onError(() => this.rejoinTimer.reset()))
    this.stateChangeRefs.push(this.socket.onOpen(() => {
      this.rejoinTimer.reset()
      if(this.isErrored()){ this.rejoin() }
    })
    )
    this.joinPush.receive("ok", () => {
      this.state = CHANNEL_STATES.joined
      this.rejoinTimer.reset()
      this.pushBuffer.forEach(pushEvent => pushEvent.send())
      this.pushBuffer = []
    })
    this.joinPush.receive("error", (reason) => {
      this.state = CHANNEL_STATES.errored
      if(this.socket.hasLogger()) this.socket.log("channel", `error ${this.topic}`, reason)
      if(this.socket.isConnected()){ this.rejoinTimer.scheduleTimeout() }
    })
    this.onClose(() => {
      this.rejoinTimer.reset()
      if(this.socket.hasLogger()) this.socket.log("channel", `close ${this.topic}`)
      this.state = CHANNEL_STATES.closed
      this.socket.remove(this)
    })
    this.onError(reason => {
      if(this.socket.hasLogger()) this.socket.log("channel", `error ${this.topic}`, reason)
      if(this.isJoining()){ this.joinPush.reset() }
      this.state = CHANNEL_STATES.errored
      if(this.socket.isConnected()){ this.rejoinTimer.scheduleTimeout() }
    })
    this.joinPush.receive("timeout", () => {
      if(this.socket.hasLogger()) this.socket.log("channel", `timeout ${this.topic}`, this.joinPush.timeout)
      let leavePush = new Push(this, CHANNEL_EVENTS.leave, closure({}), this.timeout)
      leavePush.send()
      this.state = CHANNEL_STATES.errored
      this.joinPush.reset()
      if(this.socket.isConnected()){ this.rejoinTimer.scheduleTimeout() }
    })
    this.on(CHANNEL_EVENTS.reply, (payload, ref) => {
      this.trigger(this.replyEventName(ref), payload)
    })
  }

  /**
   * Join the channel
   * @param {number} timeout
   * @returns {Push}
   */
  join(timeout = this.timeout){
    if(this.joinedOnce){
      throw new Error("tried to join multiple times. 'join' can only be called a single time per channel instance")
    } else {
      this.timeout = timeout
      this.joinedOnce = true
      this.rejoin()
      return this.joinPush
    }
  }

  /**
   * Teardown the channel.
   *
   * Destroys and stops related timers.
   */
  teardown(){
    this.pushBuffer.forEach((push) => push.destroy())
    this.pushBuffer = []
    this.rejoinTimer.reset()
    this.joinPush.destroy()
    this.state = CHANNEL_STATES.closed
    this.bindings = {}
  }

  /**
   * Hook into channel close
   * @param {ChannelBindingCallback} callback
   */
  onClose(callback){
    this.on(CHANNEL_EVENTS.close, callback)
  }

  /**
   * Hook into channel errors
   * @param {ChannelOnErrorCallback} callback
   * @return {number}
   */
  onError(callback){
    return this.on(CHANNEL_EVENTS.error, reason => callback(reason))
  }

  /**
   * Subscribes on channel events
   *
   * Subscription returns a ref counter, which can be used later to
   * unsubscribe the exact event listener
   *
   * @example
   * const ref1 = channel.on("event", do_stuff)
   * const ref2 = channel.on("event", do_other_stuff)
   * channel.off("event", ref1)
   * // Since unsubscription, do_stuff won't fire,
   * // while do_other_stuff will keep firing on the "event"
   *
   * @param {string} event
   * @param {ChannelBindingCallback} callback
   * @returns {number} ref
   */
  on(event, callback){
    let ref = this.bindingRef++
    this.bindings.push({event, ref, callback})
    return ref
  }

  /**
   * Unsubscribes off of channel events
   *
   * Use the ref returned from a channel.on() to unsubscribe one
   * handler, or pass nothing for the ref to unsubscribe all
   * handlers for the given event.
   *
   * @example
   * // Unsubscribe the do_stuff handler
   * const ref1 = channel.on("event", do_stuff)
   * channel.off("event", ref1)
   *
   * // Unsubscribe all handlers from event
   * channel.off("event")
   *
   * @param {string} event
   * @param {number} [ref]
   */
  off(event, ref){
    this.bindings = this.bindings.filter((bind) => {
      return !(bind.event === event && (typeof ref === "undefined" || ref === bind.ref))
    })
  }

  /**
   * @private
   */
  canPush(){ return this.socket.isConnected() && this.isJoined() }

  /**
   * Sends a message `event` to phoenix with the payload `payload`.
   * Phoenix receives this in the `handle_in(event, payload, socket)`
   * function. if phoenix replies or it times out (default 10000ms),
   * then optionally the reply can be received.
   *
   * @example
   * channel.push("event")
   *   .receive("ok", payload => console.log("phoenix replied:", payload))
   *   .receive("error", err => console.log("phoenix errored", err))
   *   .receive("timeout", () => console.log("timed out pushing"))
   * @param {string} event
   * @param {Object} payload
   * @param {number} [timeout]
   * @returns {Push}
   */
  push(event, payload, timeout = this.timeout){
    payload = payload || {}
    if(!this.joinedOnce){
      throw new Error(`tried to push '${event}' to '${this.topic}' before joining. Use channel.join() before pushing events`)
    }
    let pushEvent = new Push(this, event, function (){ return payload }, timeout)
    if(this.canPush()){
      pushEvent.send()
    } else {
      pushEvent.startTimeout()
      this.pushBuffer.push(pushEvent)
    }

    return pushEvent
  }

  /** Leaves the channel
   *
   * Unsubscribes from server events, and
   * instructs channel to terminate on server
   *
   * Triggers onClose() hooks
   *
   * To receive leave acknowledgements, use the `receive`
   * hook to bind to the server ack, ie:
   *
   * @example
   * channel.leave().receive("ok", () => alert("left!") )
   *
   * @param {number} timeout
   * @returns {Push}
   */
  leave(timeout = this.timeout){
    this.rejoinTimer.reset()
    this.joinPush.cancelTimeout()

    this.state = CHANNEL_STATES.leaving
    let onClose = () => {
      if(this.socket.hasLogger()) this.socket.log("channel", `leave ${this.topic}`)
      this.trigger(CHANNEL_EVENTS.close, "leave")
    }
    let leavePush = new Push(this, CHANNEL_EVENTS.leave, closure({}), timeout)
    leavePush.receive("ok", () => onClose())
      .receive("timeout", () => onClose())
    leavePush.send()
    if(!this.canPush()){ leavePush.trigger("ok", {}) }

    return leavePush
  }

  /**
   * Overridable message hook
   *
   * Receives all events for specialized message handling
   * before dispatching to the channel callbacks.
   *
   * Must return the payload, modified or unmodified
   * @type{ChannelOnMessage}
   */
  onMessage(_event, payload, _ref){ return payload }

  /**
   * Overridable filter hook
   *
   * If this function returns `true`, `binding`'s callback will be called.
   *
   * @type{ChannelFilterBindings}
   */
  filterBindings(_binding, _payload, _ref){ return true }

  isMember(topic, event, payload, joinRef){
    if(this.topic !== topic){ return false }

    if(joinRef && joinRef !== this.joinRef()){
      if(this.socket.hasLogger()) this.socket.log("channel", "dropping outdated message", {topic, event, payload, joinRef})
      return false
    } else {
      return true
    }
  }

  joinRef(){ return this.joinPush.ref }

  /**
   * @private
   */
  rejoin(timeout = this.timeout){
    if(this.isLeaving()){ return }
    this.socket.leaveOpenTopic(this.topic)
    this.state = CHANNEL_STATES.joining
    this.joinPush.resend(timeout)
  }

  /**
   * @param {string} event
   * @param {unknown} [payload]
   * @param {?string} [ref]
   * @param {?string} [joinRef]
   */
  trigger(event, payload, ref, joinRef){
    let handledPayload = this.onMessage(event, payload, ref, joinRef)
    if(payload && !handledPayload){ throw new Error("channel onMessage callbacks must return the payload, modified or unmodified") }

    let eventBindings = this.bindings.filter(bind => bind.event === event && this.filterBindings(bind, payload, ref))

    for(let i = 0; i < eventBindings.length; i++){
      let bind = eventBindings[i]
      bind.callback(handledPayload, ref, joinRef || this.joinRef())
    }
  }

  /**
  * @param {string} ref
  */
  replyEventName(ref){ return `chan_reply_${ref}` }

  isClosed(){ return this.state === CHANNEL_STATES.closed }

  isErrored(){ return this.state === CHANNEL_STATES.errored }

  isJoined(){ return this.state === CHANNEL_STATES.joined }

  isJoining(){ return this.state === CHANNEL_STATES.joining }

  isLeaving(){ return this.state === CHANNEL_STATES.leaving }
}
