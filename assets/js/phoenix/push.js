/**
 * Initializes the Push
 * @param {Channel} channel - The Channel
 * @param {string} event - The event, for example `"phx_join"`
 * @param {Object} payload - The payload, for example `{user_id: 123}`
 * @param {number} timeout - The push timeout in milliseconds
 */
export default class Push {
  constructor(channel, event, payload, timeout){
    this.channel = channel
    this.event = event
    this.payload = payload || function (){ return {} }
    this.receivedResp = null
    this.timeout = timeout
    this.timeoutTimer = null
    this.recHooks = []
    this.sent = false
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
   * @param {*} status
   * @param {*} callback
   */
  receive(status, callback){
    if(this.hasReceived(status)){
      callback(this.receivedResp.response)
    }

    this.recHooks.push({status, callback})
    return this
  }

  /**
   * @private
   */
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

  /**
   * @private
   */
  cancelTimeout(){
    clearTimeout(this.timeoutTimer)
    this.timeoutTimer = null
  }

  /**
   * @private
   */
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

  /**
   * @private
   */
  trigger(status, response){
    this.channel.trigger(this.refEvent, {status, response})
  }
}
