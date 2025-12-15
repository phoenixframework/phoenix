/**
 * @import Channel from "./channel"
 * @import { ChannelEvent } from "./types"
 */
export default class Push {
  /**
   * Initializes the Push
   * @param {Channel} channel - The Channel
   * @param {ChannelEvent} event - The event, for example `"phx_join"`
   * @param {() => Record<string, unknown>} payload - The payload, for example `{user_id: 123}`
   * @param {number} timeout - The push timeout in milliseconds
   */
  constructor(channel, event, payload, timeout){
    /** @type{Channel} */
    this.channel = channel
    /** @type{ChannelEvent} */
    this.event = event
    /** @type{() => Record<string, unknown>} */
    this.payload = payload || function (){ return {} }
    this.receivedResp = null
    /** @type{number} */
    this.timeout = timeout
    /** @type{(ReturnType<typeof setTimeout>) | null} */
    this.timeoutTimer = null
    /** @type{{status: string; callback: (response: any) => void}[]} */
    this.recHooks = []
    /** @type{boolean} */
    this.sent = false
    /** @type{string | null | undefined} */
    this.ref = undefined
  }

  /**
   *
   * @param {number} timeout
   */
  resend(timeout){
    this.timeout = timeout
    this.reset()
    this.send()
  }

  /**
   *
   */
  send(){
    if(this.hasReceived("timeout")){ return }
    this.startTimeout()
    this.sent = true
    this.channel.socket.push({
      topic: this.channel.topic,
      event: this.event,
      payload: this.payload(),
      ref: this.ref,
      join_ref: this.channel.joinRef()
    })
  }

  /**
   *
   * @param {string} status
   * @param {(response: any) => void} callback
   */
  receive(status, callback){
    if(this.hasReceived(status)){
      callback(this.receivedResp.response)
    }

    this.recHooks.push({status, callback})
    return this
  }

  reset(){
    this.cancelRefEvent()
    this.ref = null
    this.refEvent = null
    this.receivedResp = null
    this.sent = false
  }

  /**
   * @private
   */
  matchReceive({status, response, _ref}){
    this.recHooks.filter(h => h.status === status)
      .forEach(h => h.callback(response))
  }

  /**
   * @private
   */
  cancelRefEvent(){
    if(!this.refEvent){ return }
    this.channel.off(this.refEvent)
  }

  cancelTimeout(){
    clearTimeout(this.timeoutTimer)
    this.timeoutTimer = null
  }

  startTimeout(){
    if(this.timeoutTimer){ this.cancelTimeout() }
    this.ref = this.channel.socket.makeRef()
    this.refEvent = this.channel.replyEventName(this.ref)

    this.channel.on(this.refEvent, payload => {
      this.cancelRefEvent()
      this.cancelTimeout()
      this.receivedResp = payload
      this.matchReceive(payload)
    })

    this.timeoutTimer = setTimeout(() => {
      this.trigger("timeout", {})
    }, this.timeout)
  }

  /**
   * @private
   */
  hasReceived(status){
    return this.receivedResp && this.receivedResp.status === status
  }

  trigger(status, response){
    this.channel.trigger(this.refEvent, {status, response})
  }
}
