/**
 *
 * Creates a timer that accepts a `timerCalc` function to perform
 * calculated timeout retries, such as exponential backoff.
 *
 * @example
 * let reconnectTimer = new Timer(() => this.connect(), function(tries){
 *   return [1000, 5000, 10000][tries - 1] || 10000
 * })
 * reconnectTimer.scheduleTimeout() // fires after 1000
 * reconnectTimer.scheduleTimeout() // fires after 5000
 * reconnectTimer.reset()
 * reconnectTimer.scheduleTimeout() // fires after 1000
 */
export default class Timer {
  private callback: () => void
  private timerCalc: (tries: number) => number
  private timer: number | null
  private tries: number

  constructor(callback: () => void, timerCalc: (tries: number) => number) {
    this.callback = callback
    this.timerCalc = timerCalc
    this.timer = null
    this.tries = 0
  }

  reset(): void {
    this.tries = 0
    if (this.timer !== null) {
      clearTimeout(this.timer)
    }
  }

  /**
   * Cancels any previous scheduleTimeout and schedules callback
   */
  scheduleTimeout(): void {
    if (this.timer !== null) {
      clearTimeout(this.timer)
    }

    this.timer = setTimeout(() => {
      this.tries = this.tries + 1
      this.callback()
    }, this.timerCalc(this.tries + 1)) as any
  }
}