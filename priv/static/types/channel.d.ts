/**
* @import Socket from "./socket"
* @import { ChannelState, Params, ChannelBindingCallback, ChannelOnMessage, ChannelOnErrorCallback, ChannelBinding } from "./types"
*/
export default class Channel {
    /**
     * @param {string} topic
     * @param {Params | (() => Params)} params
     * @param {Socket} socket
     */
    constructor(topic: string, params: Params | (() => Params), socket: Socket);
    /** @type{ChannelState} */
    state: ChannelState;
    /** @type{string} */
    topic: string;
    /** @type{() => Params} */
    params: () => Params;
    /** @type {Socket} */
    socket: Socket;
    /** @type{ChannelBinding[]} */
    bindings: ChannelBinding[];
    /** @type{number} */
    bindingRef: number;
    /** @type{number} */
    timeout: number;
    /** @type{boolean} */
    joinedOnce: boolean;
    /** @type{Push} */
    joinPush: Push;
    /** @type{Push[]} */
    pushBuffer: Push[];
    /** @type{string[]} */
    stateChangeRefs: string[];
    /** @type{Timer} */
    rejoinTimer: Timer;
    /**
     * Join the channel
     * @param {number} timeout
     * @returns {Push}
     */
    join(timeout?: number): Push;
    /**
     * Hook into channel close
     * @param {ChannelBindingCallback} callback
     */
    onClose(callback: ChannelBindingCallback): void;
    /**
     * Hook into channel errors
     * @param {ChannelOnErrorCallback} callback
     * @return {number}
     */
    onError(callback: ChannelOnErrorCallback): number;
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
    on(event: string, callback: ChannelBindingCallback): number;
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
    off(event: string, ref?: number): void;
    /**
     * @private
     */
    private canPush;
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
    push(event: string, payload: Object, timeout?: number): Push;
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
    leave(timeout?: number): Push;
    onMessage(event: string, payload?: unknown, ref?: string | null, joinRef?: string | null): unknown;
    isMember(topic: any, event: any, payload: any, joinRef: any): boolean;
    joinRef(): string;
    /**
     * @private
     */
    private rejoin;
    /**
     * @param {string} event
     * @param {unknown} [payload]
     * @param {?string} [ref]
     * @param {?string} [joinRef]
     */
    trigger(event: string, payload?: unknown, ref?: string | null, joinRef?: string | null): void;
    /**
    * @param {string} ref
    */
    replyEventName(ref: string): string;
    isClosed(): boolean;
    isErrored(): boolean;
    isJoined(): boolean;
    isJoining(): boolean;
    isLeaving(): boolean;
}
import type { ChannelState } from "./types";
import type { Params } from "./types";
import type Socket from "./socket";
import type { ChannelBinding } from "./types";
import Push from "./push";
import Timer from "./timer";
import type { ChannelBindingCallback } from "./types";
import type { ChannelOnErrorCallback } from "./types";
//# sourceMappingURL=channel.d.ts.map