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
 *
 */
export default class Timer {
    /**
    * @param {() => void} callback
    * @param {(tries: number) => number} timerCalc
    */
    constructor(callback: () => void, timerCalc: (tries: number) => number);
    /** @type {() => void} */
    callback: () => void;
    /** @type {(tries: number) => number} */
    timerCalc: (tries: number) => number;
    /** @type {ReturnType<typeof setTimeout> | null} */
    timer: ReturnType<typeof setTimeout> | null;
    /** @type {number} */
    tries: number;
    reset(): void;
    /**
     * Cancels any previous scheduleTimeout and schedules callback
     */
    scheduleTimeout(): void;
}
//# sourceMappingURL=timer.d.ts.map