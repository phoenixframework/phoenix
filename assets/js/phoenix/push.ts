import type Channel from "./channel"

export interface PushResponse {
  status: string
  response: any
  _ref?: string
}

export interface ReceiveHook {
  status: string
  callback: (response: any) => void
}

/**
 * Initializes the Push
 * @param channel - The Channel
 * @param event - The event, for example `"phx_join"`
 * @param payload - The payload, for example `{user_id: 123}`
 * @param timeout - The push timeout in milliseconds
 */
export default class Push {
  public channel: Channel
  public event: string
  public payload: () => any
  public receivedResp: PushResponse | null
  public timeout: number
  public timeoutTimer: number | null
  public recHooks: ReceiveHook[]
  public sent: boolean
  public ref: string | null
  public refEvent: string | null

  constructor(channel: Channel, event: string, payload: any | (() => any), timeout: number) {
    this.channel = channel
    this.event = event
    this.payload = typeof payload === "function" ? payload : () => payload || {}
    this.receivedResp = null
    this.timeout = timeout
    this.timeoutTimer = null
    this.recHooks = []
    this.sent = false
    this.ref = null
    this.refEvent = null
  }

  /**
   * Resend the push with a new timeout
   */
  resend(timeout: number): void {
    this.timeout = timeout
    this.reset()
    this.send()
  }

  /**
   * Send the push
   */
  send(): void {
    if (this.hasReceived("timeout")) { return }
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
   * Register a callback for a specific response status
   */
  receive(status: string, callback: (response: any) => void): Push {
    if (this.hasReceived(status)) {
      callback(this.receivedResp!.response)
    }

    this.recHooks.push({status, callback})
    return this
  }

  /**
   * @private
   */
  reset(): void {
    this.cancelRefEvent()
    this.ref = null
    this.refEvent = null
    this.receivedResp = null
    this.sent = false
  }

  /**
   * @private
   */
  matchReceive({status, response, _ref}: PushResponse): void {
    this.recHooks.filter(h => h.status === status)
      .forEach(h => h.callback(response))
  }

  /**
   * @private
   */
  cancelRefEvent(): void {
    if (!this.refEvent) { return }
    this.channel.off(this.refEvent)
  }

  /**
   * @private
   */
  cancelTimeout(): void {
    if (this.timeoutTimer !== null) {
      clearTimeout(this.timeoutTimer)
      this.timeoutTimer = null
    }
  }

  /**
   * @private
   */
  startTimeout(): void {
    if (this.timeoutTimer) { this.cancelTimeout() }
    this.ref = this.channel.socket.makeRef()
    this.refEvent = this.channel.replyEventName(this.ref)

    this.channel.on(this.refEvent, (payload: PushResponse) => {
      this.cancelRefEvent()
      this.cancelTimeout()
      this.receivedResp = payload
      this.matchReceive(payload)
    })

    this.timeoutTimer = setTimeout(() => {
      this.trigger("timeout", {})
    }, this.timeout) as any
  }

  /**
   * @private
   */
  hasReceived(status: string): boolean {
    return this.receivedResp && this.receivedResp.status === status
  }

  /**
   * @private
   */
  trigger(status: string, response: any): void {
    this.channel.trigger(this.refEvent!, {status, response})
  }
}