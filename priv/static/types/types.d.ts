/**
 * MISC
 */
export type Params = Record<string, unknown>;
export type Closure<T> = T | (() => T);
/**
 * CHANNEL
 */
export type ChannelBindingCallback = (payload: unknown, ref: string | null | undefined, joinRef: string) => void;
/**
 * CHANNEL
 */
export type ChannelOnErrorCallback = (reason: unknown) => void;
/**
 * CHANNEL
 */
export type ChannelBinding = ({
    event: string;
    ref: number;
    callback: ChannelBindingCallback;
});
/**
 * CHANNEL
 */
export type ChannelOnMessage = (event: string, payload?: unknown, ref?: string | null, joinRef?: string | null) => unknown;
/**
 * CHANNEL
 */
export type ChannelFilterBindings = (binding: ChannelBinding, payload: unknown, ref?: string | null) => boolean;
/**
 * CONSTANTS
 */
export type Vsn = "1.0.0" | "2.0.0";
/**
 * CONSTANTS
 */
export type SocketState = (typeof SOCKET_STATES)[keyof typeof SOCKET_STATES];
/**
 * CONSTANTS
 */
export type ChannelState = (typeof CHANNEL_STATES)[keyof typeof CHANNEL_STATES];
/**
 * CONSTANTS
 */
export type ChannelEvent = (typeof CHANNEL_EVENTS)[keyof typeof CHANNEL_EVENTS];
/**
 * CONSTANTS
 */
export type Transport = (typeof TRANSPORTS)[keyof typeof TRANSPORTS];
/**
 * CONSTANTS
 */
export type XhrState = (typeof XHR_STATES)[keyof typeof XHR_STATES];
/**
 * PRESENCE
 */
export type PresenceEvents = {
    state: string;
    diff: string;
};
/**
 * PRESENCE
 */
export type PresenceOnJoin = (key: string, currentPresence: PresenceState, newPresence: PresenceState) => void;
/**
 * PRESENCE
 */
export type PresenceOnLeave = (key: string, currentPresence: PresenceState, leftPresence: PresenceState) => void;
/**
 * PRESENCE
 */
export type PresenceOnSync = () => void;
/**
 * PRESENCE
 */
export type PresenceDiff = ({
    joins: PresenceState;
    leaves: PresenceState;
});
/**
 * PRESENCE
 */
export type PresenceState = ({
    metas: {
        phx_ref?: string;
        phx_ref_prev?: string;
        [key: string]: any;
    }[];
});
/**
 * PRESENCE
 */
export type PresenceOptions = {
    events?: PresenceEvents | undefined;
};
/**
 * SERIALIZER
 */
export type Message<T> = ({
    join_ref?: string | null;
    ref?: string | null;
    event: string;
    topic: string;
    payload: T;
});
export type Encode<T> = (msg: Message<Record<string, any>>, callback: (result: ArrayBuffer | string) => T) => T;
export type Decode<T> = (rawPayload: ArrayBuffer | string, callback: (msg: Message<unknown>) => T) => T;
/**
 * SOCKET
 */
export type SocketTransport = (typeof WebSocket | typeof LongPoll);
/**
 * SOCKET
 */
export type SocketOnOpen = () => void;
/**
 * SOCKET
 */
export type SocketOnClose = (event: CloseEvent) => void;
/**
 * SOCKET
 */
export type SocketOnError = (error: Event, transportBefore: SocketTransport, establishedBefore: number) => void;
/**
 * SOCKET
 */
export type SocketOnMessage = (rawMessage: Message<unknown>) => void;
/**
 * SOCKET
 */
export type SocketStateChangeCallbacks = ({
    open: [string, SocketOnOpen][];
    close: [string, SocketOnClose][];
    error: [string, SocketOnError][];
    message: [string, SocketOnMessage][];
});
/**
 * SOCKET
 */
export type HeartbeatStatus = "sent" | "ok" | "error" | "timeout" | "disconnected";
/**
 * SOCKET
 */
export type HeartbeatCallback = (status: HeartbeatStatus, latency?: number) => void;
/**
 * SOCKET
 */
export type SocketOptions = {
    /**
     * - The Websocket Transport, for example WebSocket or Phoenix.LongPoll.
     */
    transport?: SocketTransport | undefined;
    /**
     * - The millisecond time to attempt the primary transport
     * before falling back to the LongPoll transport. Disabled by default.
     */
    longPollFallbackMs?: number | undefined;
    /**
     * - The millisecond time before LongPoll transport times out. Default 20000.
     */
    longpollerTimeout?: number | undefined;
    /**
     * - When true, enables debug logging. Default false.
     */
    debug?: boolean | undefined;
    /**
     * - The function to encode outgoing messages.
     * Defaults to JSON encoder.
     */
    encode?: Encode<void> | undefined;
    /**
     * - The function to decode incoming messages.
     * Defaults to JSON:
     *
     * ```javascript
     * (payload, callback) => callback(JSON.parse(payload))
     * ```
     */
    decode?: Decode<void> | undefined;
    /**
     * - The default timeout in milliseconds to trigger push timeouts.
     * Defaults `DEFAULT_TIMEOUT`
     */
    timeout?: number | undefined;
    /**
     * - The millisec interval to send a heartbeat message
     */
    heartbeatIntervalMs?: number | undefined;
    /**
     * - Whether to automatically send heartbeats after
     * connection is established.
     *
     * Defaults to true.
     */
    autoSendHeartbeat?: boolean | undefined;
    /**
     * - The optional function to handle heartbeat status and latency.
     */
    heartbeatCallback?: HeartbeatCallback | undefined;
    /**
     * - The optional function that returns the
     * socket reconnect interval, in milliseconds.
     *
     * Defaults to stepped backoff of:
     *
     * ```javascript
     * function(tries){
     * return [10, 50, 100, 150, 200, 250, 500, 1000, 2000][tries - 1] || 5000
     * }
     * ````
     */
    reconnectAfterMs?: ((tries: number) => number) | undefined;
    /**
     * - The optional function that returns the millisec
     * rejoin interval for individual channels.
     *
     * ```javascript
     * function(tries){
     * return [1000, 2000, 5000][tries - 1] || 10000
     * }
     * ````
     */
    rejoinAfterMs?: ((tries: number) => number) | undefined;
    /**
     * - The optional function for specialized logging, ie:
     *
     * ```javascript
     * function(kind, msg, data) {
     * console.log(`${kind}: ${msg}`, data)
     * }
     * ```
     */
    logger?: ((kind: string, msg: string, data: any) => void) | undefined;
    /**
     * - The optional params to pass when connecting
     */
    params?: Closure<Params> | undefined;
    /**
     * - the optional authentication token to be exposed on the server
     * under the `:auth_token` connect_info key.
     */
    authToken?: string | undefined;
    /**
     * - The binary type to use for binary WebSocket frames.
     *
     * Defaults to "arraybuffer"
     */
    binaryType?: BinaryType | undefined;
    /**
     * - The serializer's protocol version to send on connect.
     *
     * Defaults to DEFAULT_VSN.
     */
    vsn?: Vsn | undefined;
    /**
     * - An optional Storage compatible object
     * Phoenix uses sessionStorage for longpoll fallback history. Overriding the store is
     * useful when Phoenix won't have access to `sessionStorage`. For example, This could
     * happen if a site loads a cross-domain channel in an iframe. Example usage:
     *
     * class InMemoryStorage {
     * constructor() { this.storage = {} }
     * getItem(keyName) { return this.storage[keyName] || null }
     * removeItem(keyName) { delete this.storage[keyName] }
     * setItem(keyName, keyValue) { this.storage[keyName] = keyValue }
     * }
     */
    sessionStorage?: Storage | undefined;
    /**
     * - Callback ran before socket tries to reconnect.
     */
    beforeReconnect?: (() => Promise<void>) | undefined;
};
import type { SOCKET_STATES } from "./constants";
import type { CHANNEL_STATES } from "./constants";
import type { CHANNEL_EVENTS } from "./constants";
import type { TRANSPORTS } from "./constants";
import type { XHR_STATES } from "./constants";
import type LongPoll from "./longpoll";
//# sourceMappingURL=types.d.ts.map