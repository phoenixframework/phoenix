/**
 * @import LongPoll from "./longpoll"
 */

/**
 * MISC
 * @typedef {Record<string, unknown>} Params
 */

/**
 * @template T
 * @typedef {T | (() => T)} Closure
 *
 */

/**
 * CHANNEL
 * @typedef {(payload: unknown, ref: string | null | undefined, joinRef: string) => void} ChannelBindingCallback
 * @typedef {(reason: unknown) => void} ChannelOnErrorCallback
 * @typedef {({event: string, ref: number, callback: ChannelBindingCallback})} ChannelBinding
 * @typedef {(event: string, payload?: unknown, ref?: ?string, joinRef?: ?string) => unknown} ChannelOnMessage
 * @typedef {(binding: ChannelBinding, payload: unknown, ref?: ?string) => boolean} ChannelFilterBindings
 */


/**
 * CONSTANTS
 * @import {SOCKET_STATES, CHANNEL_STATES, CHANNEL_EVENTS, TRANSPORTS, XHR_STATES} from "./constants"
 * @typedef {"1.0.0" | "2.0.0"} Vsn
 * @typedef {typeof SOCKET_STATES[keyof typeof SOCKET_STATES]} SocketState
 * @typedef {typeof CHANNEL_STATES[keyof typeof CHANNEL_STATES]} ChannelState
 * @typedef {typeof CHANNEL_EVENTS[keyof typeof CHANNEL_EVENTS]} ChannelEvent
 * @typedef {typeof TRANSPORTS[keyof typeof TRANSPORTS]} Transport
 * @typedef {typeof XHR_STATES[keyof typeof XHR_STATES]} XhrState
 */

/**
 * PRESENCE
 * @typedef {{state: string, diff: string}} PresenceEvents
 * @typedef {(key: string, currentPresence: PresenceState, newPresence: PresenceState) => void} PresenceOnJoin
 * @typedef {(key: string, currentPresence: PresenceState, leftPresence: PresenceState) => void} PresenceOnLeave
 * @typedef {() => void} PresenceOnSync
 * @typedef {({joins: PresenceState, leaves: PresenceState})} PresenceDiff
 * @typedef {(
 *  {
 *    metas: {
 *      phx_ref?: string
 *      phx_ref_prev?: string
 *      [key: string]: any
 *    }[]
 *  }
 *)} PresenceState
 *
 * @typedef {Object} PresenceOptions
 * @property {PresenceEvents} [events]
 */

/**
 * SERIALIZER
 * @template T
 * @typedef {({
 * join_ref?: string | null;
 * ref?: string | null;
 * event: string;
 * topic: string;
 * payload: T;
 * })} Message
 */
/**
 * @template T
 * @typedef {(msg: Message<Record<string, any>>, callback: (result: ArrayBuffer | string) => T) => T} Encode
 */
/**
 * @template T
 * @typedef {(rawPayload: ArrayBuffer | string, callback: (msg: Message<unknown>) => T) => T} Decode
 */

/**
 * SOCKET
 * @typedef {(typeof WebSocket | typeof LongPoll)} SocketTransport
 * @typedef {() => void} SocketOnOpen
 * @typedef {(event: CloseEvent) => void} SocketOnClose
 * @typedef {(error: Event, transportBefore: SocketTransport, establishedBefore: number) => void} SocketOnError
 * @typedef {(rawMessage: Message<unknown>) => void} SocketOnMessage
 * @typedef {({
 *   open: [string, SocketOnOpen][]
 *   close: [string, SocketOnClose][]
 *   error: [string, SocketOnError][]
 *   message: [string, SocketOnMessage][]
 * })} SocketStateChangeCallbacks
 * @typedef {'sent' | 'ok' | 'error' | 'timeout' | 'disconnected'} HeartbeatStatus
 * @typedef {(status: HeartbeatStatus, latency?: number) => void} HeartbeatCallback
 *
 *
 *
 * @typedef {Object} SocketOptions
 * @property {SocketTransport} [transport] - The Websocket Transport, for example WebSocket or Phoenix.LongPoll.
 *
 * @property {number} [longPollFallbackMs] - The millisecond time to attempt the primary transport
 * before falling back to the LongPoll transport. Disabled by default.
 *
 * @property {number} [longpollerTimeout] - The millisecond time before LongPoll transport times out. Default 20000.
 *
 * @property {boolean} [debug] - When true, enables debug logging. Default false.
 *
 * @property {Encode<void>} [encode] - The function to encode outgoing messages.
 * Defaults to JSON encoder.
 *
 * @property {Decode<void>} [decode] - The function to decode incoming messages.
 * Defaults to JSON:
 *
 * ```javascript
 * (payload, callback) => callback(JSON.parse(payload))
 * ```
 *
 * @property {number} [timeout] - The default timeout in milliseconds to trigger push timeouts.
 * Defaults `DEFAULT_TIMEOUT`
 *
 * @property {number} [heartbeatIntervalMs] - The millisec interval to send a heartbeat message
 *
 * @property {boolean} [autoSendHeartbeat] - Whether to automatically send heartbeats after
 * connection is established.
 *
 * Defaults to true.
 *
 * @property {HeartbeatCallback} [heartbeatCallback] - The optional function to handle heartbeat status and latency.
 *
 * @property {(tries: number) => number} [reconnectAfterMs] - The optional function that returns the
 * socket reconnect interval, in milliseconds.
 *
 * Defaults to stepped backoff of:
 *
 * ```javascript
 * function(tries){
 *   return [10, 50, 100, 150, 200, 250, 500, 1000, 2000][tries - 1] || 5000
 * }
 * ````
 *
 * @property {(tries: number) => number} [rejoinAfterMs] - The optional function that returns the millisec
 * rejoin interval for individual channels.
 *
 * ```javascript
 * function(tries){
 *   return [1000, 2000, 5000][tries - 1] || 10000
 * }
 * ````
 *
 * @property {(kind: string, msg: string, data: any) => void} [logger] - The optional function for specialized logging, ie:
 *
 * ```javascript
 * function(kind, msg, data) {
 *   console.log(`${kind}: ${msg}`, data)
 * }
 * ```
 *
 * @property {Closure<Params>} [params] - The optional params to pass when connecting
 *
 * @property {string} [authToken] - the optional authentication token to be exposed on the server
 * under the `:auth_token` connect_info key.
 *
 * @property {BinaryType} [binaryType] - The binary type to use for binary WebSocket frames.
 *
 * Defaults to "arraybuffer"
 *
 * @property {Vsn} [vsn] - The serializer's protocol version to send on connect.
 *
 * Defaults to DEFAULT_VSN.
 *
 * @property {Storage} [sessionStorage] - An optional Storage compatible object
 * Phoenix uses sessionStorage for longpoll fallback history. Overriding the store is
 * useful when Phoenix won't have access to `sessionStorage`. For example, This could
 * happen if a site loads a cross-domain channel in an iframe. Example usage:
 *
 *     class InMemoryStorage {
 *       constructor() { this.storage = {} }
 *       getItem(keyName) { return this.storage[keyName] || null }
 *       removeItem(keyName) { delete this.storage[keyName] }
 *       setItem(keyName, keyValue) { this.storage[keyName] = keyValue }
 *     }
 *
 * @property {() => Promise<void>} [beforeReconnect] - Callback ran before socket tries to reconnect.
 *
 */
export {}
