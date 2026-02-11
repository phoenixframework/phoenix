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
    constructor(channel: Channel, event: ChannelEvent, payload: () => Record<string, unknown>, timeout: number);
    /** @type{Channel} */
    channel: Channel;
    /** @type{ChannelEvent} */
    event: ChannelEvent;
    /** @type{() => Record<string, unknown>} */
    payload: () => Record<string, unknown>;
    receivedResp: unknown;
    /** @type{number} */
    timeout: number;
    /** @type{(ReturnType<typeof setTimeout>) | null} */
    timeoutTimer: (ReturnType<typeof setTimeout>) | null;
    /** @type{{status: string; callback: (response: any) => void}[]} */
    recHooks: {
        status: string;
        callback: (response: any) => void;
    }[];
    /** @type{boolean} */
    sent: boolean;
    /** @type{string | null | undefined} */
    ref: string | null | undefined;
    /**
     *
     * @param {number} timeout
     */
    resend(timeout: number): void;
    /**
     *
     */
    send(): void;
    /**
     *
     * @param {string} status
     * @param {(response: any) => void} callback
     */
    receive(status: string, callback: (response: any) => void): this;
    reset(): void;
    refEvent: string | null | undefined;
    destroy(): void;
    /**
     * @private
     */
    private matchReceive;
    /**
     * @private
     */
    private cancelRefEvent;
    cancelTimeout(): void;
    startTimeout(): void;
    /**
     * @private
     */
    private hasReceived;
    trigger(status: any, response: any): void;
}
import type Channel from "./channel";
import type { ChannelEvent } from "./types";
//# sourceMappingURL=push.d.ts.map