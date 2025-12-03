/**
* @import Socket from "./socket"
* @import { ChannelState, Params, BindingCallback, Binding } from "./types"
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
    /** @type{Binding[]} */
    bindings: Binding[];
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
     * @param {BindingCallback} callback
     */
    onClose(callback: BindingCallback): void;
    /**
     * Hook into channel errors
     * @param {(reason: unknown) => void} callback
     * @return {number}
     */
    onError(callback: (reason: unknown) => void): number;
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
     * @param {BindingCallback} callback
     * @returns {number} ref
     */
    on(event: string, callback: BindingCallback): number;
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
    /**
     * Overridable message hook
     *
     * Receives all events for specialized message handling
     * before dispatching to the channel callbacks.
     *
     * Must return the payload, modified or unmodified
     * @param {string} event
     * @param {unknown} payload
     * @param {number} ref
     * @returns {unknown}
     */
    onMessage(event: string, payload: unknown, ref: number): unknown;
    /**
     * @private
     */
    private isMember;
    /**
     * @private
     */
    private joinRef;
    /**
     * @private
     */
    private rejoin;
    /**
     * @private
     */
    private trigger;
    /**
     * @private
     */
    private replyEventName;
    /**
     * @private
     */
    private isClosed;
    /**
     * @private
     */
    private isErrored;
    /**
     * @private
     */
    private isJoined;
    /**
     * @private
     */
    private isJoining;
    /**
     * @private
     */
    private isLeaving;
}
import type { ChannelState } from "./types";
import type { Params } from "./types";
import type Socket from "./socket";
import type { Binding } from "./types";
import Push from "./push";
import Timer from "./timer";
import type { BindingCallback } from "./types";
//# sourceMappingURL=channel.d.ts.map