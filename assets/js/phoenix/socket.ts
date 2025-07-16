import {
  global,
  phxWindow,
  CHANNEL_EVENTS,
  DEFAULT_TIMEOUT,
  DEFAULT_VSN,
  SOCKET_STATES,
  TRANSPORTS,
  WS_CLOSE_NORMAL,
  AUTH_TOKEN_PREFIX
} from "./constants"

import {
  closure
} from "./utils"

import Ajax from "./ajax"
import Channel from "./channel"
import LongPoll from "./longpoll"
import Serializer from "./serializer"
import Timer from "./timer"

// Type definitions for WebSocket-like transport
interface Transport {
  new(url: string, protocols?: string | string[]): TransportInstance;
  name?: string;
}

interface TransportInstance {
  binaryType: string;
  timeout?: number;
  readyState: number;
  bufferedAmount?: number;
  skipHeartbeat?: boolean;
  onopen: ((event: Event) => void) | null;
  onerror: ((event: Event) => void) | null;
  onmessage: ((event: MessageEvent) => void) | null;
  onclose: ((event: CloseEvent) => void) | null;
  send(data: string | ArrayBuffer): void;
  close(code?: number, reason?: string): void;
}

// Message structure interfaces
interface Message {
  topic: string;
  event: string;
  payload: any;
  ref: string | null;
  join_ref?: string | null;
}

interface PushData {
  topic: string;
  event: string;
  payload: any;
  ref: string;
  join_ref?: string;
}

// Callback types
type StateChangeCallback = () => void;
type ErrorCallback = (error: any, transport?: Transport, establishedConnections?: number) => void;
type MessageCallback = (message: Message) => void;
type CloseCallback = (event: CloseEvent) => void;
type LoggerFunction = (kind: string, msg: string, data?: any) => void;
type ReconnectFunction = (tries: number) => number;
type EncodeFunction = (payload: any, callback: (encoded: string | ArrayBuffer) => void) => void;
type DecodeFunction = (payload: string | ArrayBuffer, callback: (decoded: Message) => void) => void;
type ParamsFunction = () => Record<string, any>;
type PingCallback = (rtt: number) => void;

// Storage interface
interface Storage {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

// Socket options interface
interface SocketOptions {
  transport?: Transport;
  longPollFallbackMs?: number;
  debug?: boolean;
  encode?: EncodeFunction;
  decode?: DecodeFunction;
  timeout?: number;
  heartbeatIntervalMs?: number;
  reconnectAfterMs?: ReconnectFunction;
  rejoinAfterMs?: ReconnectFunction;
  logger?: LoggerFunction;
  longpollerTimeout?: number;
  params?: Record<string, any> | ParamsFunction;
  authToken?: string;
  binaryType?: string;
  vsn?: string;
  sessionStorage?: Storage;
}

// State change callbacks structure
interface StateChangeCallbacks {
  open: Array<[string, StateChangeCallback]>;
  close: Array<[string, CloseCallback]>;
  error: Array<[string, ErrorCallback]>;
  message: Array<[string, MessageCallback]>;
}

/** Initializes the Socket *
 *
 * For IE8 support use an ES5-shim (https://github.com/es-shims/es5-shim)
 *
 * @param {string} endPoint - The string WebSocket endpoint, ie, `"ws://example.com/socket"`,
 *                                               `"wss://example.com"`
 *                                               `"/socket"` (inherited host & protocol)
 * @param {Object} [opts] - Optional configuration
 * @param {Function} [opts.transport] - The Websocket Transport, for example WebSocket or Phoenix.LongPoll.
 *
 * Defaults to WebSocket with automatic LongPoll fallback if WebSocket is not defined.
 * To fallback to LongPoll when WebSocket attempts fail, use `longPollFallbackMs: 2500`.
 *
 * @param {number} [opts.longPollFallbackMs] - The millisecond time to attempt the primary transport
 * before falling back to the LongPoll transport. Disabled by default.
 *
 * @param {boolean} [opts.debug] - When true, enables debug logging. Default false.
 *
 * @param {Function} [opts.encode] - The function to encode outgoing messages.
 *
 * Defaults to JSON encoder.
 *
 * @param {Function} [opts.decode] - The function to decode incoming messages.
 *
 * Defaults to JSON:
 *
 * ```javascript
 * (payload, callback) => callback(JSON.parse(payload))
 * ```
 *
 * @param {number} [opts.timeout] - The default timeout in milliseconds to trigger push timeouts.
 *
 * Defaults `DEFAULT_TIMEOUT`
 * @param {number} [opts.heartbeatIntervalMs] - The millisec interval to send a heartbeat message
 * @param {Function} [opts.reconnectAfterMs] - The optional function that returns the
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
 * @param {Function} [opts.rejoinAfterMs] - The optional function that returns the millisec
 * rejoin interval for individual channels.
 *
 * ```javascript
 * function(tries){
 *   return [1000, 2000, 5000][tries - 1] || 10000
 * }
 * ````
 *
 * @param {Function} [opts.logger] - The optional function for specialized logging, ie:
 *
 * ```javascript
 * function(kind, msg, data) {
 *   console.log(`${kind}: ${msg}`, data)
 * }
 * ```
 *
 * @param {number} [opts.longpollerTimeout] - The maximum timeout of a long poll AJAX request.
 *
 * Defaults to 20s (double the server long poll timer).
 *
 * @param {(Object|function)} [opts.params] - The optional params to pass when connecting
 * @param {string} [opts.authToken] - the optional authentication token to be exposed on the server
 * under the `:auth_token` connect_info key.
 * @param {string} [opts.binaryType] - The binary type to use for binary WebSocket frames.
 *
 * Defaults to "arraybuffer"
 *
 * @param {vsn} [opts.vsn] - The serializer's protocol version to send on connect.
 *
 * Defaults to DEFAULT_VSN.
 *
 * @param {Object} [opts.sessionStorage] - An optional Storage compatible object
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
*/
export default class Socket {
  private stateChangeCallbacks: StateChangeCallbacks;
  private channels: Channel[];
  private sendBuffer: Array<() => void>;
  private ref: number;
  private timeout: number;
  private transport: Transport;
  private primaryPassedHealthCheck: boolean;
  private longPollFallbackMs?: number;
  private fallbackTimer: number | null;
  private sessionStore: Storage | null;
  private establishedConnections: number;
  private defaultEncoder: EncodeFunction;
  private defaultDecoder: DecodeFunction;
  private closeWasClean: boolean;
  private disconnecting: boolean;
  private binaryType: string;
  private connectClock: number;
  private encode: EncodeFunction;
  private decode: DecodeFunction;
  private heartbeatIntervalMs: number;
  private rejoinAfterMs: ReconnectFunction;
  private reconnectAfterMs: ReconnectFunction;
  private logger: LoggerFunction | null;
  private longpollerTimeout: number;
  private params: ParamsFunction;
  private endPoint: string;
  private vsn: string;
  private heartbeatTimeoutTimer: number | null;
  private heartbeatTimer: number | null;
  private pendingHeartbeatRef: string | null;
  private reconnectTimer: Timer;
  private authToken?: string;
  private conn: TransportInstance | null;

  constructor(endPoint: string, opts: SocketOptions = {}) {
    this.stateChangeCallbacks = {open: [], close: [], error: [], message: []};
    this.channels = [];
    this.sendBuffer = [];
    this.ref = 0;
    this.timeout = opts.timeout || DEFAULT_TIMEOUT;
    this.transport = opts.transport || global.WebSocket || LongPoll;
    this.primaryPassedHealthCheck = false;
    this.longPollFallbackMs = opts.longPollFallbackMs;
    this.fallbackTimer = null;
    this.sessionStore = opts.sessionStorage || (global && global.sessionStorage);
    this.establishedConnections = 0;
    this.defaultEncoder = Serializer.encode.bind(Serializer);
    this.defaultDecoder = Serializer.decode.bind(Serializer);
    this.closeWasClean = false;
    this.disconnecting = false;
    this.binaryType = opts.binaryType || "arraybuffer";
    this.connectClock = 1;
    this.conn = null;

    if (this.transport !== LongPoll) {
      this.encode = opts.encode || this.defaultEncoder;
      this.decode = opts.decode || this.defaultDecoder;
    } else {
      this.encode = this.defaultEncoder;
      this.decode = this.defaultDecoder;
    }

    let awaitingConnectionOnPageShow: number | null = null;
    if (phxWindow && phxWindow.addEventListener) {
      phxWindow.addEventListener("pagehide", (_e: Event) => {
        if (this.conn) {
          this.disconnect();
          awaitingConnectionOnPageShow = this.connectClock;
        }
      });
      phxWindow.addEventListener("pageshow", (_e: Event) => {
        if (awaitingConnectionOnPageShow === this.connectClock) {
          awaitingConnectionOnPageShow = null;
          this.connect();
        }
      });
    }

    this.heartbeatIntervalMs = opts.heartbeatIntervalMs || 30000;
    this.rejoinAfterMs = (tries: number) => {
      if (opts.rejoinAfterMs) {
        return opts.rejoinAfterMs(tries);
      } else {
        return [1000, 2000, 5000][tries - 1] || 10000;
      }
    };
    this.reconnectAfterMs = (tries: number) => {
      if (opts.reconnectAfterMs) {
        return opts.reconnectAfterMs(tries);
      } else {
        return [10, 50, 100, 150, 200, 250, 500, 1000, 2000][tries - 1] || 5000;
      }
    };
    this.logger = opts.logger || null;
    if (!this.logger && opts.debug) {
      this.logger = (kind: string, msg: string, data?: any) => { console.log(`${kind}: ${msg}`, data); };
    }
    this.longpollerTimeout = opts.longpollerTimeout || 20000;
    this.params = closure(opts.params || {}) as ParamsFunction;
    this.endPoint = `${endPoint}/${TRANSPORTS.websocket}`;
    this.vsn = opts.vsn || DEFAULT_VSN;
    this.heartbeatTimeoutTimer = null;
    this.heartbeatTimer = null;
    this.pendingHeartbeatRef = null;
    this.reconnectTimer = new Timer(() => {
      this.teardown(() => this.connect());
    }, this.reconnectAfterMs);
    this.authToken = opts.authToken;
  }

  /**
   * Returns the LongPoll transport reference
   */
  getLongPollTransport(): typeof LongPoll { 
    return LongPoll; 
  }

  /**
   * Disconnects and replaces the active transport
   *
   * @param {Function} newTransport - The new transport class to instantiate
   *
   */
  replaceTransport(newTransport: Transport): void {
    this.connectClock++;
    this.closeWasClean = true;
    clearTimeout(this.fallbackTimer!);
    this.reconnectTimer.reset();
    if (this.conn) {
      this.conn.close();
      this.conn = null;
    }
    this.transport = newTransport;
  }

  /**
   * Returns the socket protocol
   *
   * @returns {string}
   */
  protocol(): string { 
    return location.protocol.match(/^https/) ? "wss" : "ws"; 
  }

  /**
   * The fully qualified socket url
   *
   * @returns {string}
   */
  endPointURL(): string {
    let uri = Ajax.appendParams(
      Ajax.appendParams(this.endPoint, this.params()), {vsn: this.vsn});
    if (uri.charAt(0) !== "/") { return uri; }
    if (uri.charAt(1) === "/") { return `${this.protocol()}:${uri}`; }

    return `${this.protocol()}://${location.host}${uri}`;
  }

  /**
   * Disconnects the socket
   *
   * See https://developer.mozilla.org/en-US/docs/Web/API/CloseEvent#Status_codes for valid status codes.
   *
   * @param {Function} callback - Optional callback which is called after socket is disconnected.
   * @param {integer} code - A status code for disconnection (Optional).
   * @param {string} reason - A textual description of the reason to disconnect. (Optional)
   */
  disconnect(callback?: () => void, code?: number, reason?: string): void {
    this.connectClock++;
    this.disconnecting = true;
    this.closeWasClean = true;
    clearTimeout(this.fallbackTimer!);
    this.reconnectTimer.reset();
    this.teardown(() => {
      this.disconnecting = false;
      callback && callback();
    }, code, reason);
  }

  /**
   *
   * @param {Object} params - The params to send when connecting, for example `{user_id: userToken}`
   *
   * Passing params to connect is deprecated; pass them in the Socket constructor instead:
   * `new Socket("/socket", {params: {user_id: userToken}})`.
   */
  connect(params?: Record<string, any>): void {
    if (params) {
      console && console.log("passing params to connect is deprecated. Instead pass :params to the Socket constructor");
      this.params = closure(params) as ParamsFunction;
    }
    if (this.conn && !this.disconnecting) { return; }
    if (this.longPollFallbackMs && this.transport !== LongPoll) {
      this.connectWithFallback(LongPoll, this.longPollFallbackMs);
    } else {
      this.transportConnect();
    }
  }

  /**
   * Logs the message. Override `this.logger` for specialized logging. noops by default
   * @param {string} kind
   * @param {string} msg
   * @param {Object} data
   */
  log(kind: string, msg: string, data?: any): void { 
    this.logger && this.logger(kind, msg, data); 
  }

  /**
   * Returns true if a logger has been set on this socket.
   */
  hasLogger(): boolean { 
    return this.logger !== null; 
  }

  /**
   * Registers callbacks for connection open events
   *
   * @example socket.onOpen(function(){ console.info("the socket was opened") })
   *
   * @param {Function} callback
   */
  onOpen(callback: StateChangeCallback): string {
    let ref = this.makeRef();
    this.stateChangeCallbacks.open.push([ref, callback]);
    return ref;
  }

  /**
   * Registers callbacks for connection close events
   * @param {Function} callback
   */
  onClose(callback: CloseCallback): string {
    let ref = this.makeRef();
    this.stateChangeCallbacks.close.push([ref, callback]);
    return ref;
  }

  /**
   * Registers callbacks for connection error events
   *
   * @example socket.onError(function(error){ alert("An error occurred") })
   *
   * @param {Function} callback
   */
  onError(callback: ErrorCallback): string {
    let ref = this.makeRef();
    this.stateChangeCallbacks.error.push([ref, callback]);
    return ref;
  }

  /**
   * Registers callbacks for connection message events
   * @param {Function} callback
   */
  onMessage(callback: MessageCallback): string {
    let ref = this.makeRef();
    this.stateChangeCallbacks.message.push([ref, callback]);
    return ref;
  }

  /**
   * Pings the server and invokes the callback with the RTT in milliseconds
   * @param {Function} callback
   *
   * Returns true if the ping was pushed or false if unable to be pushed.
   */
  ping(callback: PingCallback): boolean {
    if (!this.isConnected()) { return false; }
    let ref = this.makeRef();
    let startTime = Date.now();
    this.push({topic: "phoenix", event: "heartbeat", payload: {}, ref: ref});
    let onMsgRef = this.onMessage(msg => {
      if (msg.ref === ref) {
        this.off([onMsgRef]);
        callback(Date.now() - startTime);
      }
    });
    return true;
  }

  /**
   * @private
   */
  private transportConnect(): void {
    this.connectClock++;
    this.closeWasClean = false;
    let protocols: string[] | undefined = undefined;
    // Sec-WebSocket-Protocol based token
    // (longpoll uses Authorization header instead)
    if (this.authToken) {
      protocols = ["phoenix", `${AUTH_TOKEN_PREFIX}${btoa(this.authToken).replace(/=/g, "")}`];
    }
    this.conn = new this.transport(this.endPointURL(), protocols);
    this.conn.binaryType = this.binaryType;
    this.conn.timeout = this.longpollerTimeout;
    this.conn.onopen = () => this.onConnOpen();
    this.conn.onerror = error => this.onConnError(error);
    this.conn.onmessage = event => this.onConnMessage(event);
    this.conn.onclose = event => this.onConnClose(event);
  }

  private getSession(key: string): string | null { 
    return this.sessionStore && this.sessionStore.getItem(key); 
  }

  private storeSession(key: string, val: string): void { 
    this.sessionStore && this.sessionStore.setItem(key, val); 
  }

  private connectWithFallback(fallbackTransport: Transport, fallbackThreshold: number = 2500): void {
    clearTimeout(this.fallbackTimer!);
    let established = false;
    let primaryTransport = true;
    let openRef: string, errorRef: string;
    let fallback = (reason: any) => {
      this.log("transport", `falling back to ${fallbackTransport.name}...`, reason);
      this.off([openRef, errorRef]);
      primaryTransport = false;
      this.replaceTransport(fallbackTransport);
      this.transportConnect();
    };
    if (this.getSession(`phx:fallback:${fallbackTransport.name}`)) { return fallback("memorized"); }

    this.fallbackTimer = setTimeout(fallback, fallbackThreshold);

    errorRef = this.onError(reason => {
      this.log("transport", "error", reason);
      if (primaryTransport && !established) {
        clearTimeout(this.fallbackTimer!);
        fallback(reason);
      }
    });
    this.onOpen(() => {
      established = true;
      if (!primaryTransport) {
        // only memorize LP if we never connected to primary
        if (!this.primaryPassedHealthCheck) { this.storeSession(`phx:fallback:${fallbackTransport.name}`, "true"); }
        return this.log("transport", `established ${fallbackTransport.name} fallback`);
      }
      // if we've established primary, give the fallback a new period to attempt ping
      clearTimeout(this.fallbackTimer!);
      this.fallbackTimer = setTimeout(fallback, fallbackThreshold);
      this.ping(rtt => {
        this.log("transport", "connected to primary after", rtt);
        this.primaryPassedHealthCheck = true;
        clearTimeout(this.fallbackTimer!);
      });
    });
    this.transportConnect();
  }

  private clearHeartbeats(): void {
    clearTimeout(this.heartbeatTimer!);
    clearTimeout(this.heartbeatTimeoutTimer!);
  }

  private onConnOpen(): void {
    if (this.hasLogger()) this.log("transport", `${this.transport.name} connected to ${this.endPointURL()}`);
    this.closeWasClean = false;
    this.disconnecting = false;
    this.establishedConnections++;
    this.flushSendBuffer();
    this.reconnectTimer.reset();
    this.resetHeartbeat();
    this.stateChangeCallbacks.open.forEach(([, callback]) => callback());
  }

  /**
   * @private
   */
  private heartbeatTimeout(): void {
    if (this.pendingHeartbeatRef) {
      this.pendingHeartbeatRef = null;
      if (this.hasLogger()) { this.log("transport", "heartbeat timeout. Attempting to re-establish connection"); }
      this.triggerChanError();
      this.closeWasClean = false;
      this.teardown(() => this.reconnectTimer.scheduleTimeout(), WS_CLOSE_NORMAL, "heartbeat timeout");
    }
  }

  private resetHeartbeat(): void {
    if (this.conn && this.conn.skipHeartbeat) { return; }
    this.pendingHeartbeatRef = null;
    this.clearHeartbeats();
    this.heartbeatTimer = setTimeout(() => this.sendHeartbeat(), this.heartbeatIntervalMs);
  }

  private teardown(callback?: () => void, code?: number, reason?: string): void {
    if (!this.conn) {
      return callback && callback();
    }
    let connectClock = this.connectClock;

    this.waitForBufferDone(() => {
      if (connectClock !== this.connectClock) { return; }
      if (this.conn) {
        if (code) { this.conn.close(code, reason || ""); } else { this.conn.close(); }
      }

      this.waitForSocketClosed(() => {
        if (connectClock !== this.connectClock) { return; }
        if (this.conn) {
          this.conn.onopen = function () { }; // noop
          this.conn.onerror = function () { }; // noop
          this.conn.onmessage = function () { }; // noop
          this.conn.onclose = function () { }; // noop
          this.conn = null;
        }

        callback && callback();
      });
    });
  }

  private waitForBufferDone(callback: () => void, tries: number = 1): void {
    if (tries === 5 || !this.conn || !this.conn.bufferedAmount) {
      callback();
      return;
    }

    setTimeout(() => {
      this.waitForBufferDone(callback, tries + 1);
    }, 150 * tries);
  }

  private waitForSocketClosed(callback: () => void, tries: number = 1): void {
    if (tries === 5 || !this.conn || this.conn.readyState === SOCKET_STATES.closed) {
      callback();
      return;
    }

    setTimeout(() => {
      this.waitForSocketClosed(callback, tries + 1);
    }, 150 * tries);
  }

  private onConnClose(event: CloseEvent): void {
    let closeCode = event && event.code;
    if (this.hasLogger()) this.log("transport", "close", event);
    this.triggerChanError();
    this.clearHeartbeats();
    if (!this.closeWasClean && closeCode !== 1000) {
      this.reconnectTimer.scheduleTimeout();
    }
    this.stateChangeCallbacks.close.forEach(([, callback]) => callback(event));
  }

  /**
   * @private
   */
  private onConnError(error: Event): void {
    if (this.hasLogger()) this.log("transport", error);
    let transportBefore = this.transport;
    let establishedBefore = this.establishedConnections;
    this.stateChangeCallbacks.error.forEach(([, callback]) => {
      callback(error, transportBefore, establishedBefore);
    });
    if (transportBefore === this.transport || establishedBefore > 0) {
      this.triggerChanError();
    }
  }

  /**
   * @private
   */
  private triggerChanError(): void {
    this.channels.forEach(channel => {
      if (!(channel.isErrored() || channel.isLeaving() || channel.isClosed())) {
        channel.trigger(CHANNEL_EVENTS.error);
      }
    });
  }

  /**
   * @returns {string}
   */
  connectionState(): string {
    switch (this.conn && this.conn.readyState) {
      case SOCKET_STATES.connecting: return "connecting";
      case SOCKET_STATES.open: return "open";
      case SOCKET_STATES.closing: return "closing";
      default: return "closed";
    }
  }

  /**
   * @returns {boolean}
   */
  isConnected(): boolean { 
    return this.connectionState() === "open"; 
  }

  /**
   * @private
   *
   * @param {Channel}
   */
  remove(channel: Channel): void {
    this.off(channel.stateChangeRefs);
    this.channels = this.channels.filter(c => c !== channel);
  }

  /**
   * Removes `onOpen`, `onClose`, `onError,` and `onMessage` registrations.
   *
   * @param {refs} - list of refs returned by calls to
   *                 `onOpen`, `onClose`, `onError,` and `onMessage`
   */
  off(refs: string[]): void {
    for (let key in this.stateChangeCallbacks) {
      this.stateChangeCallbacks[key as keyof StateChangeCallbacks] = this.stateChangeCallbacks[key as keyof StateChangeCallbacks].filter(([ref]) => {
        return refs.indexOf(ref) === -1;
      });
    }
  }

  /**
   * Initiates a new channel for the given topic
   *
   * @param {string} topic
   * @param {Object} chanParams - Parameters for the channel
   * @returns {Channel}
   */
  channel(topic: string, chanParams: Record<string, any> = {}): Channel {
    let chan = new Channel(topic, chanParams, this);
    this.channels.push(chan);
    return chan;
  }

  /**
   * @param {Object} data
   */
  push(data: PushData): void {
    if (this.hasLogger()) {
      let {topic, event, payload, ref, join_ref} = data;
      this.log("push", `${topic} ${event} (${join_ref}, ${ref})`, payload);
    }

    if (this.isConnected()) {
      this.encode(data, result => this.conn!.send(result));
    } else {
      this.sendBuffer.push(() => this.encode(data, result => this.conn!.send(result)));
    }
  }

  /**
   * Return the next message ref, accounting for overflows
   * @returns {string}
   */
  makeRef(): string {
    let newRef = this.ref + 1;
    if (newRef === this.ref) { this.ref = 0; } else { this.ref = newRef; }

    return this.ref.toString();
  }

  private sendHeartbeat(): void {
    if (this.pendingHeartbeatRef && !this.isConnected()) { return; }
    this.pendingHeartbeatRef = this.makeRef();
    this.push({topic: "phoenix", event: "heartbeat", payload: {}, ref: this.pendingHeartbeatRef});
    this.heartbeatTimeoutTimer = setTimeout(() => this.heartbeatTimeout(), this.heartbeatIntervalMs);
  }

  private flushSendBuffer(): void {
    if (this.isConnected() && this.sendBuffer.length > 0) {
      this.sendBuffer.forEach(callback => callback());
      this.sendBuffer = [];
    }
  }

  private onConnMessage(rawMessage: MessageEvent): void {
    this.decode(rawMessage.data, msg => {
      let {topic, event, payload, ref, join_ref} = msg;
      if (ref && ref === this.pendingHeartbeatRef) {
        this.clearHeartbeats();
        this.pendingHeartbeatRef = null;
        this.heartbeatTimer = setTimeout(() => this.sendHeartbeat(), this.heartbeatIntervalMs);
      }

      if (this.hasLogger()) this.log("receive", `${payload.status || ""} ${topic} ${event} ${ref && "(" + ref + ")" || ""}`, payload);

      for (let i = 0; i < this.channels.length; i++) {
        const channel = this.channels[i];
        if (!channel.isMember(topic, event, payload, join_ref)) { continue; }
        channel.trigger(event, payload, ref, join_ref);
      }

      for (let i = 0; i < this.stateChangeCallbacks.message.length; i++) {
        let [, callback] = this.stateChangeCallbacks.message[i];
        callback(msg);
      }
    });
  }

  leaveOpenTopic(topic: string): void {
    let dupChannel = this.channels.find(c => c.topic === topic && (c.isJoined() || c.isJoining()));
    if (dupChannel) {
      if (this.hasLogger()) this.log("transport", `leaving duplicate topic "${topic}"`);
      dupChannel.leave();
    }
  }
}