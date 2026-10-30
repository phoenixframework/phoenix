var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

// js/phoenix/index.js
var phoenix_exports = {};
__export(phoenix_exports, {
  Channel: () => Channel,
  LongPoll: () => LongPoll,
  Presence: () => Presence,
  ResumableWebSocket: () => ResumableWebSocket,
  Serializer: () => serializer_default,
  Socket: () => Socket
});
module.exports = __toCommonJS(phoenix_exports);

// js/phoenix/utils.js
var closure = (value) => {
  if (typeof value === "function") {
    return value;
  } else {
    let closure2 = function() {
      return value;
    };
    return closure2;
  }
};

// js/phoenix/constants.js
var globalSelf = typeof self !== "undefined" ? self : null;
var phxWindow = typeof window !== "undefined" ? window : null;
var global = globalSelf || phxWindow || globalThis;
var DEFAULT_VSN = "2.0.0";
var SOCKET_STATES = { connecting: 0, open: 1, closing: 2, closed: 3 };
var MAX_LONGPOLL_BATCH_SIZE = 100;
var DEFAULT_TIMEOUT = 1e4;
var WS_CLOSE_NORMAL = 1e3;
var CLOSE_SESSION_GONE = 3410;
var CHANNEL_STATES = {
  closed: "closed",
  errored: "errored",
  joined: "joined",
  joining: "joining",
  leaving: "leaving"
};
var CHANNEL_EVENTS = {
  close: "phx_close",
  error: "phx_error",
  join: "phx_join",
  reply: "phx_reply",
  leave: "phx_leave"
};
var TRANSPORTS = {
  longpoll: "longpoll",
  websocket: "websocket"
};
var XHR_STATES = {
  complete: 4
};
var AUTH_TOKEN_PREFIX = "base64url.bearer.phx.";

// js/phoenix/push.js
var Push = class {
  constructor(channel, event, payload, timeout) {
    this.channel = channel;
    this.event = event;
    this.payload = payload || function() {
      return {};
    };
    this.receivedResp = null;
    this.timeout = timeout;
    this.timeoutTimer = null;
    this.recHooks = [];
    this.sent = false;
  }
  /**
   *
   * @param {number} timeout
   */
  resend(timeout) {
    this.timeout = timeout;
    this.reset();
    this.send();
  }
  /**
   *
   */
  send() {
    if (this.hasReceived("timeout")) {
      return;
    }
    this.startTimeout();
    this.sent = true;
    this.channel.socket.push({
      topic: this.channel.topic,
      event: this.event,
      payload: this.payload(),
      ref: this.ref,
      join_ref: this.channel.joinRef()
    }, this.channel);
  }
  /**
   *
   * @param {*} status
   * @param {*} callback
   */
  receive(status, callback) {
    if (this.hasReceived(status)) {
      callback(this.receivedResp.response);
    }
    this.recHooks.push({ status, callback });
    return this;
  }
  /**
   * @private
   */
  reset() {
    this.cancelRefEvent();
    this.ref = null;
    this.refEvent = null;
    this.receivedResp = null;
    this.sent = false;
  }
  /**
   * @private
   */
  matchReceive({ status, response, _ref }) {
    this.recHooks.filter((h) => h.status === status).forEach((h) => h.callback(response));
  }
  /**
   * @private
   */
  cancelRefEvent() {
    if (!this.refEvent) {
      return;
    }
    this.channel.off(this.refEvent);
  }
  /**
   * @private
   */
  cancelTimeout() {
    clearTimeout(this.timeoutTimer);
    this.timeoutTimer = null;
  }
  /**
   * @private
   */
  startTimeout() {
    if (this.timeoutTimer) {
      this.cancelTimeout();
    }
    this.cancelRefEvent();
    this.ref = this.channel.socket.makeRef();
    this.refEvent = this.channel.replyEventName(this.ref);
    this.channel.on(this.refEvent, (payload) => {
      this.cancelRefEvent();
      this.cancelTimeout();
      this.receivedResp = payload;
      this.matchReceive(payload);
    });
    this.timeoutTimer = setTimeout(() => {
      this.trigger("timeout", {});
    }, this.timeout);
  }
  /**
   * @private
   */
  hasReceived(status) {
    return this.receivedResp && this.receivedResp.status === status;
  }
  /**
   * @private
   */
  trigger(status, response) {
    this.channel.trigger(this.refEvent, { status, response });
  }
};

// js/phoenix/timer.js
var Timer = class {
  constructor(callback, timerCalc) {
    this.callback = callback;
    this.timerCalc = timerCalc;
    this.timer = null;
    this.tries = 0;
  }
  reset() {
    this.tries = 0;
    clearTimeout(this.timer);
  }
  /**
   * Cancels any previous scheduleTimeout and schedules callback
   */
  scheduleTimeout() {
    clearTimeout(this.timer);
    this.timer = setTimeout(() => {
      this.tries = this.tries + 1;
      this.callback();
    }, this.timerCalc(this.tries + 1));
  }
};

// js/phoenix/channel.js
var Channel = class {
  constructor(topic, params, socket) {
    this.state = CHANNEL_STATES.closed;
    this.topic = topic;
    this.params = closure(params || {});
    this.socket = socket;
    this.bindings = [];
    this.bindingRef = 0;
    this.timeout = this.socket.timeout;
    this.joinedOnce = false;
    this.joinPush = new Push(this, CHANNEL_EVENTS.join, this.params, this.timeout);
    this.pushBuffer = [];
    this.stateChangeRefs = [];
    this.rejoinTimer = new Timer(() => {
      if (this.socket.isConnected()) {
        this.rejoin();
      }
    }, this.socket.rejoinAfterMs);
    this.stateChangeRefs.push(this.socket.onError(() => this.rejoinTimer.reset()));
    this.stateChangeRefs.push(
      this.socket.onOpen(() => {
        this.rejoinTimer.reset();
        if (this.isErrored()) {
          this.rejoin();
        }
      })
    );
    this.joinPush.receive("ok", () => {
      this.state = CHANNEL_STATES.joined;
      this.rejoinTimer.reset();
      this.pushBuffer.forEach((pushEvent) => pushEvent.send());
      this.pushBuffer = [];
    });
    this.joinPush.receive("error", () => {
      this.state = CHANNEL_STATES.errored;
      if (this.socket.isConnected()) {
        this.rejoinTimer.scheduleTimeout();
      }
    });
    this.onClose(() => {
      this.rejoinTimer.reset();
      if (this.socket.hasLogger()) this.socket.log("channel", `close ${this.topic} ${this.joinRef()}`);
      this.state = CHANNEL_STATES.closed;
      this.socket.remove(this);
    });
    this.onError((reason) => {
      if (this.socket.hasLogger()) this.socket.log("channel", `error ${this.topic}`, reason);
      if (this.isJoining()) {
        this.joinPush.reset();
      }
      this.state = CHANNEL_STATES.errored;
      if (this.socket.isConnected()) {
        this.rejoinTimer.scheduleTimeout();
      }
    });
    this.joinPush.receive("timeout", () => {
      if (this.socket.hasLogger()) this.socket.log("channel", `timeout ${this.topic} (${this.joinRef()})`, this.joinPush.timeout);
      let leavePush = new Push(this, CHANNEL_EVENTS.leave, closure({}), this.timeout);
      leavePush.send();
      this.state = CHANNEL_STATES.errored;
      this.joinPush.reset();
      if (this.socket.isConnected()) {
        this.rejoinTimer.scheduleTimeout();
      }
    });
    this.on(CHANNEL_EVENTS.reply, (payload, ref) => {
      this.trigger(this.replyEventName(ref), payload);
    });
  }
  /**
   * Join the channel
   * @param {integer} timeout
   * @returns {Push}
   */
  join(timeout = this.timeout) {
    if (this.joinedOnce) {
      throw new Error("tried to join multiple times. 'join' can only be called a single time per channel instance");
    } else {
      this.timeout = timeout;
      this.joinedOnce = true;
      this.rejoin();
      return this.joinPush;
    }
  }
  /**
   * Hook into channel close
   * @param {Function} callback
   */
  onClose(callback) {
    this.on(CHANNEL_EVENTS.close, callback);
  }
  /**
   * Hook into channel errors
   * @param {Function} callback
   */
  onError(callback) {
    return this.on(CHANNEL_EVENTS.error, (reason) => callback(reason));
  }
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
   * @param {Function} callback
   * @returns {integer} ref
   */
  on(event, callback) {
    let ref = this.bindingRef++;
    this.bindings.push({ event, ref, callback });
    return ref;
  }
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
   * @param {integer} ref
   */
  off(event, ref) {
    this.bindings = this.bindings.filter((bind) => {
      return !(bind.event === event && (typeof ref === "undefined" || ref === bind.ref));
    });
  }
  /**
   * @private
   */
  canPush() {
    return this.socket.isConnected() && this.isJoined();
  }
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
  push(event, payload, timeout = this.timeout) {
    payload = payload || {};
    if (!this.joinedOnce) {
      throw new Error(`tried to push '${event}' to '${this.topic}' before joining. Use channel.join() before pushing events`);
    }
    let pushEvent = new Push(this, event, function() {
      return payload;
    }, timeout);
    if (this.canPush()) {
      pushEvent.send();
    } else {
      pushEvent.startTimeout();
      this.pushBuffer.push(pushEvent);
    }
    return pushEvent;
  }
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
   * @param {integer} timeout
   * @returns {Push}
   */
  leave(timeout = this.timeout) {
    this.rejoinTimer.reset();
    this.joinPush.cancelTimeout();
    this.state = CHANNEL_STATES.leaving;
    let onClose = () => {
      if (this.socket.hasLogger()) this.socket.log("channel", `leave ${this.topic}`);
      this.trigger(CHANNEL_EVENTS.close, "leave");
    };
    let leavePush = new Push(this, CHANNEL_EVENTS.leave, closure({}), timeout);
    leavePush.receive("ok", () => onClose()).receive("timeout", () => onClose());
    leavePush.send();
    if (!this.canPush()) {
      leavePush.trigger("ok", {});
    }
    return leavePush;
  }
  /**
   * Overridable message hook
   *
   * Receives all events for specialized message handling
   * before dispatching to the channel callbacks.
   *
   * Must return the payload, modified or unmodified
   * @param {string} event
   * @param {Object} payload
   * @param {integer} ref
   * @returns {Object}
   */
  onMessage(_event, payload, _ref) {
    return payload;
  }
  /**
   * @private
   */
  isMember(topic, event, payload, joinRef) {
    if (this.topic !== topic) {
      return false;
    }
    if (joinRef && joinRef !== this.joinRef()) {
      if (this.socket.hasLogger()) this.socket.log("channel", "dropping outdated message", { topic, event, payload, joinRef });
      return false;
    } else {
      return true;
    }
  }
  /**
   * @private
   */
  joinRef() {
    return this.joinPush.ref;
  }
  /**
   * @private
   */
  rejoin(timeout = this.timeout) {
    if (this.isLeaving()) {
      return;
    }
    this.socket.leaveOpenTopic(this.topic);
    this.state = CHANNEL_STATES.joining;
    this.joinPush.resend(timeout);
  }
  /**
   * @private
   */
  trigger(event, payload, ref, joinRef) {
    let handledPayload = this.onMessage(event, payload, ref, joinRef);
    if (payload && !handledPayload) {
      throw new Error("channel onMessage callbacks must return the payload, modified or unmodified");
    }
    let eventBindings = this.bindings.filter((bind) => bind.event === event);
    for (let i = 0; i < eventBindings.length; i++) {
      let bind = eventBindings[i];
      bind.callback(handledPayload, ref, joinRef || this.joinRef());
    }
  }
  /**
   * @private
   */
  replyEventName(ref) {
    return `chan_reply_${ref}`;
  }
  /**
   * @private
   */
  isClosed() {
    return this.state === CHANNEL_STATES.closed;
  }
  /**
   * @private
   */
  isErrored() {
    return this.state === CHANNEL_STATES.errored;
  }
  /**
   * @private
   */
  isJoined() {
    return this.state === CHANNEL_STATES.joined;
  }
  /**
   * @private
   */
  isJoining() {
    return this.state === CHANNEL_STATES.joining;
  }
  /**
   * @private
   */
  isLeaving() {
    return this.state === CHANNEL_STATES.leaving;
  }
};

// js/phoenix/ajax.js
var Ajax = class {
  static request(method, endPoint, headers, body, timeout, ontimeout, callback) {
    if (global.XDomainRequest) {
      let req = new global.XDomainRequest();
      return this.xdomainRequest(req, method, endPoint, body, timeout, ontimeout, callback);
    } else if (global.XMLHttpRequest) {
      let req = new global.XMLHttpRequest();
      return this.xhrRequest(req, method, endPoint, headers, body, timeout, ontimeout, callback);
    } else if (global.fetch && global.AbortController) {
      return this.fetchRequest(method, endPoint, headers, body, timeout, ontimeout, callback);
    } else {
      throw new Error("No suitable XMLHttpRequest implementation found");
    }
  }
  static fetchRequest(method, endPoint, headers, body, timeout, ontimeout, callback) {
    let options = {
      method,
      headers,
      body
    };
    let controller = null;
    let timeoutId = null;
    if (timeout) {
      controller = new AbortController();
      timeoutId = setTimeout(() => controller.abort(), timeout);
      options.signal = controller.signal;
    }
    global.fetch(endPoint, options).then((response) => response.text()).then((data) => this.parseJSON(data)).then((data) => {
      if (timeoutId) {
        clearTimeout(timeoutId);
      }
      callback && callback(data);
    }).catch((err) => {
      if (timeoutId) {
        clearTimeout(timeoutId);
      }
      if (err.name === "AbortError" && ontimeout) {
        ontimeout();
      } else {
        callback && callback(null);
      }
    });
    return controller;
  }
  static xdomainRequest(req, method, endPoint, body, timeout, ontimeout, callback) {
    req.timeout = timeout;
    req.open(method, endPoint);
    req.onload = () => {
      let response = this.parseJSON(req.responseText);
      callback && callback(response);
    };
    if (ontimeout) {
      req.ontimeout = ontimeout;
    }
    req.onprogress = () => {
    };
    req.send(body);
    return req;
  }
  static xhrRequest(req, method, endPoint, headers, body, timeout, ontimeout, callback) {
    req.open(method, endPoint, true);
    req.timeout = timeout;
    for (let [key, value] of Object.entries(headers)) {
      req.setRequestHeader(key, value);
    }
    req.onerror = () => callback && callback(null);
    req.onreadystatechange = () => {
      if (req.readyState === XHR_STATES.complete && callback) {
        let response = this.parseJSON(req.responseText);
        callback(response);
      }
    };
    if (ontimeout) {
      req.ontimeout = ontimeout;
    }
    req.send(body);
    return req;
  }
  static parseJSON(resp) {
    if (!resp || resp === "") {
      return null;
    }
    try {
      return JSON.parse(resp);
    } catch {
      console && console.log("failed to parse JSON response", resp);
      return null;
    }
  }
  static serialize(obj, parentKey) {
    let queryStr = [];
    for (var key in obj) {
      if (!Object.prototype.hasOwnProperty.call(obj, key)) {
        continue;
      }
      let paramKey = parentKey ? `${parentKey}[${key}]` : key;
      let paramVal = obj[key];
      if (typeof paramVal === "object") {
        queryStr.push(this.serialize(paramVal, paramKey));
      } else {
        queryStr.push(encodeURIComponent(paramKey) + "=" + encodeURIComponent(paramVal));
      }
    }
    return queryStr.join("&");
  }
  static appendParams(url, params) {
    if (Object.keys(params).length === 0) {
      return url;
    }
    let prefix = url.match(/\?/) ? "&" : "?";
    return `${url}${prefix}${this.serialize(params)}`;
  }
};

// js/phoenix/longpoll.js
var BINARY_PREFIX = "base64:";
var RETRY_DELAYS = [100, 500, 1e3, 2e3, 5e3];
var base64ToArrayBuffer = (base64) => {
  let binary = atob(base64);
  let bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
};
var arrayBufferToBase64 = (buffer) => {
  let binary = "";
  let bytes = new Uint8Array(buffer);
  let len = bytes.byteLength;
  for (let i = 0; i < len; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
};
var LongPoll = class {
  constructor(endPoint, protocols) {
    if (protocols && protocols.length === 2 && protocols[1].startsWith(AUTH_TOKEN_PREFIX)) {
      this.authToken = atob(protocols[1].slice(AUTH_TOKEN_PREFIX.length));
    }
    this.endPoint = null;
    this.token = null;
    this.skipHeartbeat = true;
    this.reqs = /* @__PURE__ */ new Set();
    this.messageTimers = /* @__PURE__ */ new Set();
    this.awaitingBatchAck = false;
    this.currentBatch = null;
    this.currentBatchTimer = null;
    this.batchBuffer = [];
    this.resumable = false;
    this.degraded = false;
    this.ack = 0;
    this.seq = 0;
    this.retries = { GET: 0, POST: 0 };
    this.retryTimers = /* @__PURE__ */ new Set();
    this.interrupted = false;
    this.resuming = false;
    this.resumeBuffer = [];
    this.onopen = function() {
    };
    this.onerror = function() {
    };
    this.onmessage = function() {
    };
    this.onclose = function() {
    };
    this.onsuspend = function() {
    };
    this.onresume = function() {
    };
    this.pollEndpoint = this.normalizeEndpoint(endPoint);
    this.readyState = SOCKET_STATES.connecting;
    setTimeout(() => this.poll(), 0);
  }
  /**
   * @private
   *
   * Continues a session that another transport started, such as a ResumableWebSocket,
   * before the first poll. We resume the session with its token and the number of the
   * last message we received, and send the messages the server did not confirm again,
   * numbered after the last one it confirmed. The server drops the ones it received.
   */
  resumeSession({ token, received, confirmed, unconfirmed }) {
    this.token = token;
    this.resumable = true;
    this.resuming = true;
    this.ack = received;
    this.seq = confirmed;
    this.resumeBuffer = unconfirmed.slice();
  }
  normalizeEndpoint(endPoint) {
    return endPoint.replace("ws://", "http://").replace("wss://", "https://").replace(new RegExp("(.*)/" + TRANSPORTS.websocket), "$1/" + TRANSPORTS.longpoll);
  }
  endpointURL(params = {}) {
    return Ajax.appendParams(this.pollEndpoint, params);
  }
  closeAndRetry(error, code, reason, wasClean) {
    if (!this.isActive()) {
      return;
    }
    this.stop(SOCKET_STATES.connecting);
    this.onerror(error);
    if (this.isActive()) {
      this.emitClose(code, reason, wasClean);
    }
  }
  ontimeout() {
    this.closeAndRetry("timeout", 1005, "timeout", false);
  }
  isActive() {
    return this.readyState === SOCKET_STATES.open || this.readyState === SOCKET_STATES.connecting;
  }
  poll() {
    if (!this.isActive()) {
      return;
    }
    const headers = { "Accept": "application/json" };
    if (this.authToken) {
      headers["X-Phoenix-AuthToken"] = this.authToken;
    }
    const params = this.resumable ? { ack: this.ack } : {};
    if (this.resumable && (this.resuming || this.retries.GET > 0)) {
      params.resume = 1;
    }
    this.ajax("GET", headers, null, params, () => this.retryOr("GET", () => this.poll(), () => this.ontimeout()), (resp) => {
      if (resp) {
        var { status, token, messages, last } = resp;
        if (status === 410 && this.token !== null) {
          this.closeAndRetry(410, CLOSE_SESSION_GONE, "session_gone", false);
          return;
        }
        this.token = token;
        if (last !== void 0) {
          this.resumable = !this.degraded;
        } else if (this.resuming && (status === 200 || status === 204)) {
          this.closeAndRetry(410, CLOSE_SESSION_GONE, "session_gone", false);
          return;
        } else if (this.resumable && (status === 200 || status === 204)) {
          if (!this.degrade()) {
            return;
          }
        }
      } else {
        status = 0;
      }
      if (this.resuming && (status === 200 || status === 204)) {
        this.readyState = SOCKET_STATES.open;
        this.onopen({});
        if (!this.isActive()) {
          return;
        }
        this.resuming = false;
        const buffered = this.resumeBuffer;
        this.resumeBuffer = [];
        buffered.forEach((body) => this.send(body));
      }
      switch (status) {
        case 200:
          if (last !== void 0) {
            const first = last - messages.length + 1;
            if (first > this.ack + 1) {
              this.closeAndRetry(0, 1011, "lost messages", false);
              return;
            }
            messages = messages.slice(Math.max(0, this.ack + 1 - first));
            this.ack = Math.max(this.ack, last);
          }
          messages.forEach((msg) => {
            const data = msg.startsWith(BINARY_PREFIX) ? base64ToArrayBuffer(msg.slice(BINARY_PREFIX.length)) : msg;
            this.scheduleMessage(() => this.onmessage({ data }));
          });
          this.scheduleMessage(() => {
            this.succeeded("GET");
            this.poll();
          });
          break;
        case 204:
          this.succeeded("GET");
          this.poll();
          break;
        case 410:
          this.readyState = SOCKET_STATES.open;
          this.onopen({});
          this.poll();
          break;
        case 403:
          this.onerror(403);
          this.close(1008, "forbidden", false);
          break;
        case 0:
          this.retryOr("GET", () => this.poll(), () => this.closeAndRetry(500, 1011, "internal server error", false));
          break;
        case 500:
          this.closeAndRetry(500, 1011, "internal server error", false);
          break;
        default:
          throw new Error(`unhandled poll status ${status}`);
      }
    });
  }
  scheduleMessage(callback) {
    const timer = setTimeout(() => {
      this.messageTimers.delete(timer);
      callback();
    }, 0);
    this.messageTimers.add(timer);
  }
  // we collect all pushes within the current event loop by
  // setTimeout 0, which optimizes back-to-back procedural
  // pushes against an empty buffer
  send(body) {
    if (this.resuming) {
      this.resumeBuffer.push(body);
      return;
    }
    if (typeof body !== "string") {
      body = arrayBufferToBase64(body);
    }
    this.seq++;
    if (this.currentBatch) {
      this.currentBatch.push(body);
    } else if (this.awaitingBatchAck) {
      if (this.batchBuffer.length === 0) {
        this.batchBufferSeq = this.seq;
      }
      this.batchBuffer.push(body);
    } else {
      this.currentBatch = [body];
      const seq = this.seq;
      this.currentBatchTimer = setTimeout(() => {
        this.batchSend(this.currentBatch, seq);
        this.currentBatch = null;
      }, 0);
    }
  }
  batchSend(messages, seq, offset = 0) {
    if (!this.isActive()) {
      return;
    }
    this.awaitingBatchAck = true;
    const next = offset + MAX_LONGPOLL_BATCH_SIZE;
    const batch = messages.slice(offset, next);
    const retry = () => this.batchSend(messages, seq, offset);
    const params = this.resumable ? { seq: seq + offset } : {};
    this.ajax("POST", { "Content-Type": "application/x-ndjson" }, batch.join("\n"), params, () => this.retryOr("POST", retry, () => this.ontimeout()), (resp) => {
      if (!resp) {
        this.retryOr("POST", retry, () => this.closeAndRetry(null, 1011, "internal server error", false));
      } else if (resp.status !== 200) {
        this.closeAndRetry(resp && resp.status, 1011, "internal server error", false);
      } else {
        if (this.resumable && resp.seq === void 0 && !this.degrade()) {
          return;
        }
        this.succeeded("POST");
        if (next < messages.length) {
          this.batchSend(messages, seq, next);
        } else if (this.batchBuffer.length > 0) {
          this.batchSend(this.batchBuffer, this.batchBufferSeq);
          this.batchBuffer = [];
        } else {
          this.awaitingBatchAck = false;
        }
      }
    });
  }
  /**
   * @private
   *
   * Stops resuming for the rest of the session. A node with an older server, as
   * during a rolling deploy, does not forward our ack and seq. Retrying through it
   * could lose or duplicate messages, so we fail like we do with an older server.
   *
   * TODO: Remove in Phoenix 1.10, when no cluster mixes 1.8 and newer nodes.
   */
  degrade() {
    this.degraded = true;
    this.resumable = false;
    if (this.retries.GET > 0 || this.retries.POST > 0) {
      this.closeAndRetry(0, 1011, "session no longer resumable", false);
      return false;
    }
    return true;
  }
  /**
   * @private
   *
   * Retries a failed request with backoff when the server keeps our session,
   * otherwise fails.
   */
  retryOr(method, retry, fail) {
    if (!this.resumable) {
      return fail();
    }
    const delay = RETRY_DELAYS[Math.min(this.retries[method], RETRY_DELAYS.length - 1)];
    this.retries[method]++;
    if (this.retries[method] > 1 && !this.interrupted) {
      this.interrupted = true;
      this.onsuspend();
    }
    if (!this.isActive()) {
      return;
    }
    const timer = setTimeout(() => {
      this.retryTimers.delete(timer);
      if (!this.resumable) {
        return fail();
      }
      retry();
    }, delay);
    this.retryTimers.add(timer);
  }
  /**
   * @private
   */
  succeeded(method) {
    this.retries[method] = 0;
    if (this.interrupted && this.retries.GET === 0 && this.retries.POST === 0) {
      this.interrupted = false;
      this.onresume();
    }
  }
  close(code, reason, wasClean) {
    this.stop(SOCKET_STATES.closed);
    this.emitClose(code, reason, wasClean);
  }
  /**
   * Cancels the pending requests, queued messages and outgoing batches.
   */
  stop(readyState) {
    this.readyState = readyState;
    const reqs = this.reqs;
    this.reqs = /* @__PURE__ */ new Set();
    for (let { req } of reqs) {
      req && req.abort();
    }
    for (let timer of this.messageTimers) {
      clearTimeout(timer);
    }
    this.messageTimers.clear();
    for (let timer of this.retryTimers) {
      clearTimeout(timer);
    }
    this.retryTimers.clear();
    this.interrupted = false;
    this.batchBuffer = [];
    this.awaitingBatchAck = false;
    clearTimeout(this.currentBatchTimer);
    this.currentBatchTimer = null;
    this.currentBatch = null;
  }
  /**
   * Emits the close event. Like a WebSocket closed without a code, it reports 1005 (no status)
   * unless one is given, as 1000 would look like the server closing the connection normally.
   */
  emitClose(code = 1005, reason, wasClean = true) {
    let opts = { code, reason, wasClean };
    if (typeof CloseEvent !== "undefined") {
      this.onclose(new CloseEvent("close", opts));
    } else {
      this.onclose(opts);
    }
  }
  ajax(method, headers, body, params, onCallerTimeout, callback) {
    const request = { req: null };
    this.reqs.add(request);
    let ontimeout = () => {
      if (this.reqs.delete(request)) {
        onCallerTimeout();
      }
    };
    if (this.token !== null) {
      headers = Object.assign({}, headers, { "X-Phoenix-Longpoll-Token": this.token });
    }
    request.req = Ajax.request(method, this.endpointURL(params), headers, body, this.timeout, ontimeout, (resp) => {
      if (this.reqs.delete(request)) {
        callback(resp);
      }
    });
  }
};

// js/phoenix/presence.js
var Presence = class _Presence {
  constructor(channel, opts = {}) {
    let events = opts.events || { state: "presence_state", diff: "presence_diff" };
    this.state = /* @__PURE__ */ Object.create(null);
    this.pendingDiffs = [];
    this.channel = channel;
    this.joinRef = null;
    this.caller = {
      onJoin: function() {
      },
      onLeave: function() {
      },
      onSync: function() {
      }
    };
    this.channel.on(events.state, (newState) => {
      let { onJoin, onLeave, onSync } = this.caller;
      this.joinRef = this.channel.joinRef();
      this.state = _Presence.syncState(this.state, newState, onJoin, onLeave);
      this.pendingDiffs.forEach((diff) => {
        this.state = _Presence.syncDiff(this.state, diff, onJoin, onLeave);
      });
      this.pendingDiffs = [];
      onSync();
    });
    this.channel.on(events.diff, (diff) => {
      let { onJoin, onLeave, onSync } = this.caller;
      if (this.inPendingSyncState()) {
        this.pendingDiffs.push(diff);
      } else {
        this.state = _Presence.syncDiff(this.state, diff, onJoin, onLeave);
        onSync();
      }
    });
  }
  onJoin(callback) {
    this.caller.onJoin = callback;
  }
  onLeave(callback) {
    this.caller.onLeave = callback;
  }
  onSync(callback) {
    this.caller.onSync = callback;
  }
  list(by) {
    return _Presence.list(this.state, by);
  }
  inPendingSyncState() {
    return !this.joinRef || this.joinRef !== this.channel.joinRef();
  }
  // lower-level public static API
  /**
   * Used to sync the list of presences on the server
   * with the client's state. An optional `onJoin` and `onLeave` callback can
   * be provided to react to changes in the client's local presences across
   * disconnects and reconnects with the server.
   *
   * @returns {Presence}
   */
  static syncState(currentState, newState, onJoin, onLeave) {
    let state = this.toNullProtoObj(this.clone(currentState));
    newState = this.toNullProtoObj(newState);
    let joins = /* @__PURE__ */ Object.create(null);
    let leaves = /* @__PURE__ */ Object.create(null);
    this.map(state, (key, presence) => {
      if (!newState[key]) {
        leaves[key] = presence;
      }
    });
    this.map(newState, (key, newPresence) => {
      let currentPresence = state[key];
      if (currentPresence) {
        let newRefs = newPresence.metas.map((m) => m.phx_ref);
        let curRefs = currentPresence.metas.map((m) => m.phx_ref);
        let joinedMetas = newPresence.metas.filter((m) => curRefs.indexOf(m.phx_ref) < 0);
        let leftMetas = currentPresence.metas.filter((m) => newRefs.indexOf(m.phx_ref) < 0);
        if (joinedMetas.length > 0) {
          joins[key] = newPresence;
          joins[key].metas = joinedMetas;
        }
        if (leftMetas.length > 0) {
          leaves[key] = this.clone(currentPresence);
          leaves[key].metas = leftMetas;
        }
      } else {
        joins[key] = newPresence;
      }
    });
    return this.syncDiff(state, { joins, leaves }, onJoin, onLeave);
  }
  /**
   *
   * Used to sync a diff of presence join and leave
   * events from the server, as they happen. Like `syncState`, `syncDiff`
   * accepts optional `onJoin` and `onLeave` callbacks to react to a user
   * joining or leaving from a device.
   *
   * @returns {Presence}
   */
  static syncDiff(state, diff, onJoin, onLeave) {
    state = this.toNullProtoObj(state);
    let { joins, leaves } = this.clone(diff);
    if (!onJoin) {
      onJoin = function() {
      };
    }
    if (!onLeave) {
      onLeave = function() {
      };
    }
    this.map(joins, (key, newPresence) => {
      let currentPresence = state[key];
      state[key] = this.clone(newPresence);
      if (currentPresence) {
        let joinedRefs = state[key].metas.map((m) => m.phx_ref);
        let curMetas = currentPresence.metas.filter((m) => joinedRefs.indexOf(m.phx_ref) < 0);
        state[key].metas.unshift(...curMetas);
      }
      onJoin(key, currentPresence, newPresence);
    });
    this.map(leaves, (key, leftPresence) => {
      let currentPresence = state[key];
      if (!currentPresence) {
        return;
      }
      let refsToRemove = leftPresence.metas.map((m) => m.phx_ref);
      currentPresence.metas = currentPresence.metas.filter((p) => {
        return refsToRemove.indexOf(p.phx_ref) < 0;
      });
      onLeave(key, currentPresence, leftPresence);
      if (currentPresence.metas.length === 0) {
        delete state[key];
      }
    });
    return state;
  }
  /**
   * Returns the array of presences, with selected metadata.
   *
   * @param {Object} presences
   * @param {Function} chooser
   *
   * @returns {Presence}
   */
  static list(presences, chooser) {
    if (!chooser) {
      chooser = function(key, pres) {
        return pres;
      };
    }
    return this.map(presences, (key, presence) => {
      return chooser(key, presence);
    });
  }
  // private
  static map(obj, func) {
    return Object.getOwnPropertyNames(obj).map((key) => func(key, obj[key]));
  }
  // Presence keys are chosen on the server and may collide with
  // Object.prototype properties ("__proto__", "constructor", ...), so any
  // object indexed by presence key must not have a prototype chain
  //
  // TODO: replace the null-prototype objects with Maps in Phoenix 2.0
  // (breaking change for the lower-level static API)
  static toNullProtoObj(obj) {
    if (Object.getPrototypeOf(obj) === null) {
      return obj;
    }
    let cleaned = /* @__PURE__ */ Object.create(null);
    Object.getOwnPropertyNames(obj).forEach((key) => {
      cleaned[key] = obj[key];
    });
    return cleaned;
  }
  static clone(obj) {
    return JSON.parse(JSON.stringify(obj));
  }
};

// js/phoenix/resumable_websocket.js
var RETRY_DELAYS2 = [100, 500, 1e3, 2e3, 5e3];
var ACK_INTERVAL_MS = 1e3;
var DEFAULT_RESUME_TIMEOUT_MS = 1e4;
var CONTROL_PREFIX = '[null,null,"phoenix","phx_';
var control = (event, payload) => JSON.stringify([null, null, "phoenix", event, payload]);
var ResumableWebSocket = class _ResumableWebSocket {
  constructor(endPoint, protocols) {
    this.endPoint = endPoint;
    this.protocols = protocols;
    this.binaryTypeValue = "arraybuffer";
    this.timeout = DEFAULT_RESUME_TIMEOUT_MS;
    this.readyState = SOCKET_STATES.connecting;
    this.token = null;
    this.unsupported = false;
    this.received = 0;
    this.unconfirmed = [];
    this.confirmed = 0;
    this.ws = null;
    this.ready = false;
    this.resuming = false;
    this.retries = 0;
    this.retryTimer = null;
    this.resumeTimer = null;
    this.ackTimer = null;
    this.interrupted = false;
    this.longPollFallbackMs = null;
    this.fallbackTimer = null;
    this.longpoll = null;
    this.onopen = function() {
    };
    this.onerror = function() {
    };
    this.onmessage = function() {
    };
    this.onclose = function() {
    };
    this.onsuspend = function() {
    };
    this.onresume = function() {
    };
    this.connect(false);
  }
  get binaryType() {
    return this.binaryTypeValue;
  }
  set binaryType(binaryType) {
    this.binaryTypeValue = binaryType;
    if (this.ws) {
      this.ws.binaryType = binaryType;
    }
  }
  get bufferedAmount() {
    return this.ws ? this.ws.bufferedAmount : 0;
  }
  send(data) {
    if (this.readyState !== SOCKET_STATES.open) {
      return;
    }
    if (this.longpoll) {
      this.longpoll.send(data);
      return;
    }
    if (!this.unsupported) {
      this.unconfirmed.push(data);
    }
    if (this.ready) {
      this.ws.send(data);
    }
  }
  close(code, reason) {
    if (this.readyState === SOCKET_STATES.closed) {
      return;
    }
    if (this.ready && this.token) {
      this.ws.send(control("phx_close", {}));
    }
    if (this.longpoll) {
      const longpoll = this.longpoll;
      this.longpoll = null;
      longpoll.onclose = function() {
      };
      longpoll.close(code, reason);
    }
    this.stop(code, reason);
    this.onclose({ code: code || 1005, reason: reason || "", wasClean: true });
  }
  /**
   * @private
   *
   * Resumes the session over a new WebSocket when the heartbeat timed out, as the
   * current one is presumed dead. Returns whether we resume the session.
   */
  resumeAfterHeartbeatTimeout() {
    if (this.readyState !== SOCKET_STATES.open || !this.token) {
      return false;
    }
    if (this.longpoll) {
      return true;
    }
    if (this.ws && !this.resuming) {
      this.dropWebSocket();
      this.retry();
    }
    return true;
  }
  /**
   * @private
   */
  connect(resume) {
    const WebSocket = _ResumableWebSocket.WebSocket || global.WebSocket;
    const params = resume ? { resumable: 1, resume: 1 } : { resumable: 1 };
    const ws = new WebSocket(Ajax.appendParams(this.endPoint, params), this.protocols);
    ws.binaryType = this.binaryTypeValue;
    this.ws = ws;
    this.ready = false;
    this.resuming = resume;
    if (resume) {
      this.resumeTimer = setTimeout(() => {
        this.dropWebSocket();
        this.retry();
      }, this.timeout);
    }
    ws.onopen = () => {
      if (this.ws !== ws) {
        return;
      }
      if (resume) {
        ws.send(control("phx_resume", { token: this.token, ack: this.received }));
      } else {
        this.ready = true;
        this.readyState = SOCKET_STATES.open;
        this.onopen();
      }
    };
    ws.onerror = (error) => {
      if (this.ws === ws && !this.token) {
        this.onerror(error);
      }
    };
    ws.onmessage = (event) => {
      if (this.ws === ws) {
        this.handleMessage(event);
      }
    };
    ws.onclose = (event) => {
      if (this.ws === ws) {
        this.handleClose(event);
      }
    };
  }
  /**
   * @private
   */
  handleMessage(event) {
    const { data } = event;
    if (typeof data === "string" && data.startsWith(CONTROL_PREFIX)) {
      const [, , , name, payload] = JSON.parse(data);
      this.handleControl(name, payload);
      return;
    }
    if (this.resuming) {
      this.end();
      return;
    }
    if (this.token === null && !this.unsupported) {
      this.unsupported = true;
      this.unconfirmed = [];
    }
    this.received++;
    this.scheduleAck();
    this.onmessage(event);
  }
  /**
   * @private
   */
  handleControl(name, payload) {
    switch (name) {
      case "phx_session":
        this.token = payload.token;
        break;
      case "phx_resumed":
        this.resumed(payload.seq);
        break;
      case "phx_ack":
        this.confirm(payload.seq);
        break;
      case "phx_gone":
        this.end(payload.code);
        break;
      default:
        if (this.resuming) {
          this.end();
        }
    }
  }
  /**
   * @private
   */
  resumed(seq) {
    if (!this.resuming) {
      return;
    }
    if (seq < this.confirmed || seq > this.confirmed + this.unconfirmed.length) {
      this.end();
      return;
    }
    clearTimeout(this.resumeTimer);
    this.confirm(seq);
    this.resuming = false;
    this.ready = true;
    this.unconfirmed.forEach((data) => this.ws.send(data));
    this.retries = 0;
    this.recovered();
  }
  /**
   * @private
   */
  interrupt() {
    if (!this.interrupted) {
      this.interrupted = true;
      this.onsuspend();
    }
  }
  /**
   * @private
   */
  recovered() {
    clearTimeout(this.fallbackTimer);
    this.fallbackTimer = null;
    if (this.interrupted) {
      this.interrupted = false;
      this.onresume();
    }
  }
  /**
   * @private
   */
  confirm(seq) {
    if (seq > this.confirmed) {
      this.unconfirmed.splice(0, seq - this.confirmed);
      this.confirmed = seq;
    }
  }
  /**
   * @private
   */
  scheduleAck() {
    if (this.ackTimer || !this.token) {
      return;
    }
    this.ackTimer = setTimeout(() => {
      this.ackTimer = null;
      if (this.ready) {
        this.ws.send(control("phx_ack", { ack: this.received }));
      }
    }, ACK_INTERVAL_MS);
  }
  /**
   * @private
   */
  handleClose(event) {
    this.ws = null;
    this.ready = false;
    clearTimeout(this.ackTimer);
    clearTimeout(this.resumeTimer);
    this.ackTimer = null;
    if (this.readyState === SOCKET_STATES.open && this.token) {
      this.retry();
    } else {
      this.stop();
      this.onclose(event);
    }
  }
  /**
   * @private
   *
   * Resumes the session over a new WebSocket with backoff.
   */
  retry() {
    this.resuming = false;
    const delay = RETRY_DELAYS2[Math.min(this.retries, RETRY_DELAYS2.length - 1)];
    this.retries++;
    if (this.retries > 1) {
      this.interrupt();
    }
    if (this.readyState !== SOCKET_STATES.open) {
      return;
    }
    if (this.longPollFallbackMs && !this.fallbackTimer) {
      this.fallbackTimer = setTimeout(() => this.fallBack(), this.longPollFallbackMs);
    }
    this.retryTimer = setTimeout(() => {
      this.retryTimer = null;
      this.connect(true);
    }, delay);
  }
  /**
   * @private
   *
   * Continues the session with long polling, as resuming it over a WebSocket did not
   * succeed in time. The LongPoll sends the messages the server did not confirm.
   */
  fallBack() {
    this.fallbackTimer = null;
    if (this.readyState !== SOCKET_STATES.open) {
      return;
    }
    clearTimeout(this.retryTimer);
    this.retryTimer = null;
    this.dropWebSocket();
    this.resuming = false;
    const longpoll = new LongPoll(this.endPoint, this.protocols);
    longpoll.timeout = this.timeout;
    longpoll.resumeSession({
      token: this.token,
      received: this.received,
      confirmed: this.confirmed,
      unconfirmed: this.unconfirmed
    });
    this.unconfirmed = [];
    this.longpoll = longpoll;
    const current = () => this.longpoll === longpoll;
    longpoll.onopen = () => {
      if (current()) {
        this.recovered();
      }
    };
    longpoll.onmessage = (event) => {
      if (current()) {
        this.onmessage(event);
      }
    };
    longpoll.onerror = (error) => {
      if (current()) {
        this.onerror(error);
      }
    };
    longpoll.onsuspend = () => {
      if (current()) {
        this.interrupt();
      }
    };
    longpoll.onresume = () => {
      if (current()) {
        this.recovered();
      }
    };
    longpoll.onclose = (event) => {
      if (!current()) {
        return;
      }
      this.longpoll = null;
      this.stop();
      this.onclose(event);
    };
  }
  /**
   * @private
   *
   * Closes the transport when the session is gone, so the socket connects again.
   */
  end(code) {
    this.stop();
    if (code) {
      this.onclose({ code, reason: "", wasClean: true });
    } else {
      this.onclose({ code: CLOSE_SESSION_GONE, reason: "session_gone", wasClean: false });
    }
  }
  /**
   * @private
   */
  dropWebSocket(code, reason) {
    const ws = this.ws;
    this.ws = null;
    this.ready = false;
    clearTimeout(this.resumeTimer);
    if (!ws) {
      return;
    }
    ws.onopen = ws.onerror = ws.onmessage = ws.onclose = function() {
    };
    if (ws.readyState === SOCKET_STATES.connecting || ws.readyState === SOCKET_STATES.open) {
      if (code) {
        ws.close(code, reason || "");
      } else {
        ws.close();
      }
    }
  }
  /**
   * @private
   */
  stop(code, reason) {
    this.readyState = SOCKET_STATES.closed;
    clearTimeout(this.retryTimer);
    clearTimeout(this.ackTimer);
    clearTimeout(this.fallbackTimer);
    this.retryTimer = null;
    this.ackTimer = null;
    this.fallbackTimer = null;
    this.interrupted = false;
    this.dropWebSocket(code, reason);
  }
};

// js/phoenix/serializer.js
var serializer_default = {
  HEADER_LENGTH: 1,
  META_LENGTH: 4,
  KINDS: { push: 0, reply: 1, broadcast: 2 },
  encode(msg, callback) {
    if (msg.payload.constructor === ArrayBuffer) {
      return callback(this.binaryEncode(msg));
    } else {
      let payload = [msg.join_ref, msg.ref, msg.topic, msg.event, msg.payload];
      return callback(JSON.stringify(payload));
    }
  },
  decode(rawPayload, callback) {
    if (rawPayload.constructor === ArrayBuffer) {
      return callback(this.binaryDecode(rawPayload));
    } else {
      let [join_ref, ref, topic, event, payload] = JSON.parse(rawPayload);
      return callback({ join_ref, ref, topic, event, payload });
    }
  },
  // private
  binaryEncode(message) {
    let { join_ref, ref, event, topic, payload } = message;
    let encoder = new TextEncoder();
    let joinRefBytes = encoder.encode(join_ref);
    let refBytes = encoder.encode(ref);
    let topicBytes = encoder.encode(topic);
    let eventBytes = encoder.encode(event);
    this.assertFieldSize(joinRefBytes.byteLength, "join_ref");
    this.assertFieldSize(refBytes.byteLength, "ref");
    this.assertFieldSize(topicBytes.byteLength, "topic");
    this.assertFieldSize(eventBytes.byteLength, "event");
    let metaLength = this.META_LENGTH + joinRefBytes.byteLength + refBytes.byteLength + topicBytes.byteLength + eventBytes.byteLength;
    let header = new ArrayBuffer(this.HEADER_LENGTH + metaLength);
    let headerBytes = new Uint8Array(header);
    let view = new DataView(header);
    let offset = 0;
    view.setUint8(offset++, this.KINDS.push);
    view.setUint8(offset++, joinRefBytes.byteLength);
    view.setUint8(offset++, refBytes.byteLength);
    view.setUint8(offset++, topicBytes.byteLength);
    view.setUint8(offset++, eventBytes.byteLength);
    headerBytes.set(joinRefBytes, offset);
    offset += joinRefBytes.byteLength;
    headerBytes.set(refBytes, offset);
    offset += refBytes.byteLength;
    headerBytes.set(topicBytes, offset);
    offset += topicBytes.byteLength;
    headerBytes.set(eventBytes, offset);
    offset += eventBytes.byteLength;
    var combined = new Uint8Array(header.byteLength + payload.byteLength);
    combined.set(headerBytes, 0);
    combined.set(new Uint8Array(payload), header.byteLength);
    return combined.buffer;
  },
  assertFieldSize(size, name) {
    if (size > 255) {
      throw new Error(`unable to convert ${name} to binary: must be less than or equal to 255 bytes, but is ${size} bytes`);
    }
  },
  binaryDecode(buffer) {
    let view = new DataView(buffer);
    let kind = view.getUint8(0);
    let decoder = new TextDecoder();
    switch (kind) {
      case this.KINDS.push:
        return this.decodePush(buffer, view, decoder);
      case this.KINDS.reply:
        return this.decodeReply(buffer, view, decoder);
      case this.KINDS.broadcast:
        return this.decodeBroadcast(buffer, view, decoder);
    }
  },
  decodePush(buffer, view, decoder) {
    let joinRefSize = view.getUint8(1);
    let topicSize = view.getUint8(2);
    let eventSize = view.getUint8(3);
    let offset = this.HEADER_LENGTH + this.META_LENGTH - 1;
    let joinRef = decoder.decode(buffer.slice(offset, offset + joinRefSize));
    offset = offset + joinRefSize;
    let topic = decoder.decode(buffer.slice(offset, offset + topicSize));
    offset = offset + topicSize;
    let event = decoder.decode(buffer.slice(offset, offset + eventSize));
    offset = offset + eventSize;
    let data = buffer.slice(offset, buffer.byteLength);
    return { join_ref: joinRef, ref: null, topic, event, payload: data };
  },
  decodeReply(buffer, view, decoder) {
    let joinRefSize = view.getUint8(1);
    let refSize = view.getUint8(2);
    let topicSize = view.getUint8(3);
    let eventSize = view.getUint8(4);
    let offset = this.HEADER_LENGTH + this.META_LENGTH;
    let joinRef = decoder.decode(buffer.slice(offset, offset + joinRefSize));
    offset = offset + joinRefSize;
    let ref = decoder.decode(buffer.slice(offset, offset + refSize));
    offset = offset + refSize;
    let topic = decoder.decode(buffer.slice(offset, offset + topicSize));
    offset = offset + topicSize;
    let event = decoder.decode(buffer.slice(offset, offset + eventSize));
    offset = offset + eventSize;
    let data = buffer.slice(offset, buffer.byteLength);
    let payload = { status: event, response: data };
    return { join_ref: joinRef, ref, topic, event: CHANNEL_EVENTS.reply, payload };
  },
  decodeBroadcast(buffer, view, decoder) {
    let topicSize = view.getUint8(1);
    let eventSize = view.getUint8(2);
    let offset = this.HEADER_LENGTH + 2;
    let topic = decoder.decode(buffer.slice(offset, offset + topicSize));
    offset = offset + topicSize;
    let event = decoder.decode(buffer.slice(offset, offset + eventSize));
    offset = offset + eventSize;
    let data = buffer.slice(offset, buffer.byteLength);
    return { join_ref: null, ref: null, topic, event, payload: data };
  }
};

// js/phoenix/connection.js
var Connection = class {
  /**
   * @param {Socket} socket
   * @param {Object} transport - The transport instance, for example a WebSocket
   */
  constructor(socket, transport) {
    this.socket = socket;
    this.transport = transport;
    this.joins = /* @__PURE__ */ new WeakMap();
    this.pings = /* @__PURE__ */ new Map();
    this.closing = false;
    this.ended = false;
    this.channelsErrored = false;
    this.closeHandled = false;
    this.suspended = false;
    transport.onopen = () => {
      if (this.isCurrent()) {
        socket.onConnOpen();
      }
    };
    transport.onerror = (error) => {
      if (this.isCurrent()) {
        socket.onConnError(error);
      }
    };
    transport.onmessage = (event) => {
      if (this.isCurrent()) {
        socket.onConnMessage(event);
      }
    };
    transport.onsuspend = () => {
      if (this.isCurrent()) {
        socket.onConnSuspend(this);
      }
    };
    transport.onresume = () => {
      if (this.isCurrent()) {
        socket.onConnResume(this);
      }
    };
    transport.onclose = (event) => {
      if (this.isCurrent() && !this.closeHandled) {
        this.closeHandled = true;
        socket.onConnClose(event);
      }
    };
  }
  /**
   * Whether this is the connection the socket currently uses. A replaced connection
   * can still emit events while it closes, but they no longer concern the socket.
   */
  isCurrent() {
    return this.socket.connection === this;
  }
  isOpen() {
    return this.transport.readyState === SOCKET_STATES.open;
  }
  isConnecting() {
    return this.transport.readyState === SOCKET_STATES.connecting;
  }
  /**
   * Whether the channel's current join was sent over this connection.
   */
  carried(channel, joinRef = channel.joinRef()) {
    return this.joins.has(channel) && this.joins.get(channel) === joinRef;
  }
  /**
   * Closes the transport. Its close event then only confirms our close.
   */
  close(code, reason) {
    this.closing = true;
    this.transport.onerror = function() {
    };
    if (code) {
      this.transport.close(code, reason || "");
    } else {
      this.transport.close();
    }
  }
};

// js/phoenix/socket.js
var Socket = class {
  constructor(endPoint, opts = {}) {
    this.stateChangeCallbacks = { open: [], close: [], error: [], message: [], suspend: [], resume: [] };
    this.channels = [];
    this.sendBuffer = [];
    this.ref = 0;
    this.fallbackRef = null;
    this.fallbackErrorRef = null;
    this.timeout = opts.timeout || DEFAULT_TIMEOUT;
    this.transport = opts.transport || (global.WebSocket && opts.resumable ? ResumableWebSocket : global.WebSocket) || LongPoll;
    this.primaryPassedHealthCheck = false;
    this.longPollFallbackMs = opts.longPollFallbackMs;
    this.fallbackTimer = null;
    this.sessionStore = opts.sessionStorage || global && global.sessionStorage;
    this.establishedConnections = 0;
    this.defaultEncoder = serializer_default.encode.bind(serializer_default);
    this.defaultDecoder = serializer_default.decode.bind(serializer_default);
    this.closeWasClean = true;
    this.binaryType = opts.binaryType || "arraybuffer";
    this.connection = null;
    this.connectClock = 1;
    this.visibilityConnection = null;
    if (this.transport !== LongPoll) {
      this.encode = opts.encode || this.defaultEncoder;
      this.decode = opts.decode || this.defaultDecoder;
    } else {
      this.encode = this.defaultEncoder;
      this.decode = this.defaultDecoder;
    }
    let awaitingConnectionOnPageShow = null;
    if (phxWindow && phxWindow.addEventListener) {
      phxWindow.addEventListener("pagehide", (_e) => {
        if (this.connection && !this.connection.ended) {
          this.disconnect();
          awaitingConnectionOnPageShow = this.connectClock;
        }
      });
      phxWindow.addEventListener("pageshow", (_e) => {
        if (awaitingConnectionOnPageShow === this.connectClock) {
          awaitingConnectionOnPageShow = null;
          this.connect();
        }
      });
      phxWindow.addEventListener("visibilitychange", () => {
        this.handleVisibilityChange();
      });
      phxWindow.document && phxWindow.document.addEventListener("resume", () => {
        this.handleVisibilityChange();
      });
    }
    this.heartbeatIntervalMs = opts.heartbeatIntervalMs || 3e4;
    this.rejoinAfterMs = (tries) => {
      if (opts.rejoinAfterMs) {
        return opts.rejoinAfterMs(tries);
      } else {
        return [1e3, 2e3, 5e3][tries - 1] || 1e4;
      }
    };
    this.reconnectAfterMs = (tries) => {
      if (opts.reconnectAfterMs) {
        return opts.reconnectAfterMs(tries);
      } else {
        return [10, 50, 100, 150, 200, 250, 500, 1e3, 2e3][tries - 1] || 5e3;
      }
    };
    this.reconnectWhenHidden = opts.reconnectWhenHidden || false;
    this.logger = opts.logger || null;
    if (!this.logger && opts.debug) {
      this.logger = (kind, msg, data) => {
        console.log(`${kind}: ${msg}`, data);
      };
    }
    this.longpollerTimeout = opts.longpollerTimeout || 2e4;
    this.params = closure(opts.params || {});
    this.endPoint = `${endPoint}/${TRANSPORTS.websocket}`;
    this.vsn = opts.vsn || DEFAULT_VSN;
    this.heartbeatTimeoutTimer = null;
    this.heartbeatTimer = null;
    this.pendingHeartbeatRef = null;
    this.reconnectTimer = new Timer(() => {
      if (this.pageHidden && !this.reconnectWhenHidden) {
        this.log("Not reconnecting as page is hidden!");
        this.teardown();
        return;
      }
      this.teardownAndReconnect(() => this.connect());
    }, this.reconnectAfterMs);
    this.authToken = opts.authToken && closure(opts.authToken);
  }
  /**
   * The transport instance of the current connection, for example a WebSocket
   */
  get conn() {
    return this.connection && this.connection.transport;
  }
  /**
   * @internal
   */
  get pageHidden() {
    return phxWindow && phxWindow.document ? phxWindow.document.visibilityState === "hidden" : false;
  }
  /**
   * @internal
   */
  handleVisibilityChange() {
    if (this.pageHidden) {
      this.visibilityConnection = null;
      return;
    }
    const connection = this.connection;
    if (connection && connection === this.visibilityConnection && connection.isConnecting()) {
      return;
    }
    if (!this.isConnected() && !this.closeWasClean) {
      this.reconnectTimer.reset();
      this.teardownAndReconnect(() => {
        this.connect();
        this.visibilityConnection = this.connection;
      });
    }
  }
  /**
   * Returns the LongPoll transport reference
   */
  getLongPollTransport() {
    return LongPoll;
  }
  /**
   * Disconnects and replaces the active transport
   *
   * @param {Function} newTransport - The new transport class to instantiate
   *
   */
  replaceTransport(newTransport) {
    const connectClock = ++this.connectClock;
    this.closeWasClean = true;
    clearTimeout(this.fallbackTimer);
    this.reconnectTimer.reset();
    this.transport = newTransport;
    const connection = this.connection;
    if (connection) {
      const wasOpen = connection.isOpen();
      this.connection = null;
      connection.ended = true;
      connection.close();
      this.clearHeartbeats();
      if (wasOpen) {
        this.triggerChanError("connection_closed", connection);
      }
    }
    return connectClock;
  }
  /**
   * Returns the socket protocol
   *
   * @returns {string}
   */
  protocol() {
    return location.protocol.match(/^https/) ? "wss" : "ws";
  }
  /**
   * The fully qualified socket url
   *
   * @returns {string}
   */
  endPointURL() {
    let uri = Ajax.appendParams(
      Ajax.appendParams(this.endPoint, this.params()),
      { vsn: this.vsn }
    );
    if (uri.charAt(0) !== "/") {
      return uri;
    }
    if (uri.charAt(1) === "/") {
      return `${this.protocol()}:${uri}`;
    }
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
  disconnect(callback, code, reason) {
    this.connectClock++;
    this.closeWasClean = true;
    clearTimeout(this.fallbackTimer);
    this.reconnectTimer.reset();
    if (this.connection) {
      this.connection.ended = true;
    }
    this.teardown(callback, code, reason);
  }
  /**
   *
   * @param {Object} params - The params to send when connecting, for example `{user_id: userToken}`
   *
   * Passing params to connect is deprecated; pass them in the Socket constructor instead:
   * `new Socket("/socket", {params: {user_id: userToken}})`.
   */
  connect(params) {
    if (params) {
      console && console.log("passing params to connect is deprecated. Instead pass :params to the Socket constructor");
      this.params = closure(params);
    }
    if (this.connection && !this.connection.ended) {
      return;
    }
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
  log(kind, msg, data) {
    this.logger && this.logger(kind, msg, data);
  }
  /**
   * Returns true if a logger has been set on this socket.
   */
  hasLogger() {
    return this.logger !== null;
  }
  /**
   * Registers callbacks for connection open events
   *
   * @example socket.onOpen(function(){ console.info("the socket was opened") })
   *
   * @param {Function} callback
   */
  onOpen(callback) {
    let ref = this.makeRef();
    this.stateChangeCallbacks.open.push([ref, callback]);
    return ref;
  }
  /**
   * Registers callbacks for connection close events
   * @param {Function} callback
   */
  onClose(callback) {
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
  onError(callback) {
    let ref = this.makeRef();
    this.stateChangeCallbacks.error.push([ref, callback]);
    return ref;
  }
  /**
   * Registers a callback when the transport is interrupted but keeps its session
   * and retries. Channels remain joined and pushes are buffered by the transport.
   * Currently supported by LongPoll. A lost session instead emits error/close.
   * @param {Function} callback
   */
  onSuspend(callback) {
    let ref = this.makeRef();
    this.stateChangeCallbacks.suspend.push([ref, callback]);
    return ref;
  }
  /**
   * Registers a callback when a suspended transport recovers the same session.
   * @param {Function} callback
   */
  onResume(callback) {
    let ref = this.makeRef();
    this.stateChangeCallbacks.resume.push([ref, callback]);
    return ref;
  }
  /**
   * Registers callbacks for connection message events
   * @param {Function} callback
   */
  onMessage(callback) {
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
  ping(callback) {
    if (!this.isConnected()) {
      return false;
    }
    let ref = this.makeRef();
    let startTime = Date.now();
    this.connection.pings.set(ref, () => callback(Date.now() - startTime));
    this.push({ topic: "phoenix", event: "heartbeat", payload: {}, ref });
    return true;
  }
  /**
   * @private
   *
   * @param {Function}
   */
  transportName(transport) {
    switch (transport) {
      case LongPoll:
        return "LongPoll";
      case ResumableWebSocket:
        return "ResumableWebSocket";
      default:
        return transport.name;
    }
  }
  /**
   * @private
   */
  transportConnect() {
    const previous = this.connection;
    this.connectClock++;
    this.closeWasClean = false;
    clearTimeout(this.reconnectTimer.timer);
    let protocols = void 0;
    if (this.authToken) {
      protocols = ["phoenix", `${AUTH_TOKEN_PREFIX}${btoa(this.authToken()).replace(/=/g, "")}`];
    }
    const transport = new this.transport(this.endPointURL(), protocols);
    transport.binaryType = this.binaryType;
    transport.timeout = this.longpollerTimeout;
    transport.longPollFallbackMs = this.longPollFallbackMs;
    this.connection = new Connection(this, transport);
    if (previous && previous.isOpen()) {
      this.triggerChanError("connection_closed", previous);
    }
  }
  getSession(key) {
    return this.sessionStore && this.sessionStore.getItem(key);
  }
  storeSession(key, val) {
    this.sessionStore && this.sessionStore.setItem(key, val);
  }
  connectWithFallback(fallbackTransport, fallbackThreshold = 2500) {
    this.cancelFallback();
    let established = false;
    let primaryTransport = true;
    let errorRef;
    let connectClock;
    const isCurrent = () => connectClock === this.connectClock && !this.closeWasClean;
    let fallbackTransportName = this.transportName(fallbackTransport);
    let fallback = (reason) => {
      this.log("transport", `falling back to ${fallbackTransportName}...`, reason);
      this.off([errorRef]);
      primaryTransport = false;
      const replaceClock = this.replaceTransport(fallbackTransport);
      if (replaceClock !== this.connectClock) {
        return;
      }
      this.transportConnect();
    };
    if (this.getSession(`phx:fallback:${fallbackTransportName}`)) {
      return fallback("memorized");
    }
    this.fallbackTimer = setTimeout(fallback, fallbackThreshold);
    errorRef = this.fallbackErrorRef = this.onError((reason) => {
      if (!isCurrent()) {
        return;
      }
      this.log("transport", "error", reason);
      if (primaryTransport && !established) {
        clearTimeout(this.fallbackTimer);
        fallback(reason);
      }
    });
    this.fallbackRef = this.onOpen(() => {
      if (!primaryTransport) {
        if (this.transport !== fallbackTransport || this.closeWasClean) {
          return;
        }
        let fallbackTransportName2 = this.transportName(fallbackTransport);
        if (!this.primaryPassedHealthCheck) {
          this.storeSession(`phx:fallback:${fallbackTransportName2}`, "true");
        }
        return this.log("transport", `established ${fallbackTransportName2} fallback`);
      }
      if (!isCurrent()) {
        return;
      }
      established = true;
      clearTimeout(this.fallbackTimer);
      this.fallbackTimer = setTimeout(fallback, fallbackThreshold);
      this.ping((rtt) => {
        this.log("transport", "connected to primary after", rtt);
        this.primaryPassedHealthCheck = true;
        clearTimeout(this.fallbackTimer);
      });
    });
    this.transportConnect();
    connectClock = this.connectClock;
  }
  /**
   * @private
   *
   * Stops the fallback of the current connection attempt, see connectWithFallback
   */
  cancelFallback() {
    clearTimeout(this.fallbackTimer);
    this.off([this.fallbackRef, this.fallbackErrorRef]);
  }
  clearHeartbeats() {
    clearTimeout(this.heartbeatTimer);
    clearTimeout(this.heartbeatTimeoutTimer);
    this.pendingHeartbeatRef = null;
  }
  onConnOpen() {
    if (this.hasLogger()) this.log("transport", `${this.transportName(this.transport)} connected to ${this.endPointURL()}`);
    this.closeWasClean = false;
    this.establishedConnections++;
    this.flushSendBuffer();
    this.reconnectTimer.reset();
    this.resetHeartbeat();
    this.stateChangeCallbacks.open.forEach(([, callback]) => callback());
  }
  /**
   * @private
   */
  heartbeatTimeout() {
    if (this.pendingHeartbeatRef) {
      const connection = this.connection;
      this.pendingHeartbeatRef = null;
      const transport = connection && connection.transport;
      if (transport && transport.resumeAfterHeartbeatTimeout && transport.resumeAfterHeartbeatTimeout()) {
        if (this.hasLogger()) {
          this.log("transport", "heartbeat timeout. Resuming the session");
        }
        this.resetHeartbeat();
        return;
      }
      if (this.hasLogger()) {
        this.log("transport", "heartbeat timeout. Attempting to re-establish connection");
      }
      this.closeWasClean = false;
      if (connection) {
        connection.close(WS_CLOSE_NORMAL, "heartbeat timeout");
      }
      if (!this.stillUses(connection)) {
        return;
      }
      this.triggerChanError("heartbeat_timeout");
      if (!this.stillUses(connection)) {
        return;
      }
      this.teardownAndReconnect(() => this.reconnectTimer.scheduleTimeout());
    }
  }
  resetHeartbeat() {
    if (this.conn && this.conn.skipHeartbeat) {
      return;
    }
    this.clearHeartbeats();
    this.heartbeatTimer = setTimeout(() => this.sendHeartbeat(), this.heartbeatIntervalMs);
  }
  /**
   * @private
   *
   * Tears down the current connection to reconnect afterwards, unless the socket was
   * disconnected or connected again in the meantime, which takes precedence.
   */
  teardownAndReconnect(reconnect) {
    const connection = this.connection;
    const connectClock = this.connectClock;
    this.teardown(() => {
      if (connectClock !== this.connectClock || connection && connection.ended) {
        return;
      }
      reconnect();
    });
  }
  /**
   * @private
   *
   * Whether the socket still uses the connection and did not give up on it. User callbacks
   * can disconnect or connect, so code continuing after them checks this first.
   */
  stillUses(connection) {
    return this.connection === connection && !(connection && connection.ended);
  }
  teardown(callback, code, reason) {
    const connection = this.connection;
    if (!connection) {
      return callback && callback();
    }
    this.clearHeartbeats();
    this.waitForBufferDone(connection.transport, () => {
      if (!connection.closing) {
        const wasOpened = !connection.isConnecting();
        connection.close(code, reason);
        if (wasOpened) {
          this.triggerChanError("connection_closed", connection);
        }
      }
      this.waitForSocketClosed(connection.transport, () => {
        if (this.connection === connection) {
          this.connection = null;
        }
        callback && callback();
      });
    });
  }
  waitForBufferDone(conn, callback, tries = 1) {
    if (tries === 5 || !conn.bufferedAmount || conn.readyState !== SOCKET_STATES.open) {
      callback();
      return;
    }
    setTimeout(() => {
      this.waitForBufferDone(conn, callback, tries + 1);
    }, 150 * tries);
  }
  waitForSocketClosed(conn, callback, tries = 1) {
    if (tries === 5 || conn.readyState === SOCKET_STATES.closed) {
      callback();
      return;
    }
    setTimeout(() => {
      this.waitForSocketClosed(conn, callback, tries + 1);
    }, 150 * tries);
  }
  onConnClose(event) {
    const connection = this.connection;
    if (this.hasLogger()) this.log("transport", "close", event);
    this.clearHeartbeats();
    const closedByUs = !!(connection && connection.closing);
    this.triggerChanError("connection_closed", connection);
    if (this.stillUses(connection) && !closedByUs && !this.closeWasClean) {
      this.reconnectTimer.scheduleTimeout();
    }
    this.stateChangeCallbacks.close.forEach(([, callback]) => callback(event));
  }
  /**
   * @private
   */
  onConnError(error) {
    const connection = this.connection;
    if (this.hasLogger()) this.log("transport", "error", error);
    let transportBefore = this.transport;
    let establishedBefore = this.establishedConnections;
    this.stateChangeCallbacks.error.forEach(([, callback]) => {
      callback(error, transportBefore, establishedBefore);
    });
    this.triggerChanError("connection_error", connection);
  }
  /** @private */
  onConnSuspend(connection) {
    if (!this.stillUses(connection) || !connection.isOpen() || connection.suspended) {
      return;
    }
    connection.suspended = true;
    if (this.hasLogger()) this.log("transport", "suspended");
    for (let [, callback] of this.stateChangeCallbacks.suspend.slice()) {
      if (!this.stillUses(connection) || !connection.isOpen()) {
        break;
      }
      callback();
    }
  }
  /** @private */
  onConnResume(connection) {
    if (!this.stillUses(connection) || !connection.isOpen() || !connection.suspended) {
      return;
    }
    connection.suspended = false;
    if (this.hasLogger()) this.log("transport", "resumed");
    for (let [, callback] of this.stateChangeCallbacks.resume.slice()) {
      if (!this.stillUses(connection) || !connection.isOpen()) {
        break;
      }
      callback();
    }
  }
  /**
   * @private
   *
   * Errors the channels, as they need to rejoin once the given connection stopped being open.
   */
  triggerChanError(reason, connection = this.connection) {
    let erroredBefore = false;
    if (connection && !connection.isOpen()) {
      erroredBefore = connection.channelsErrored;
      connection.channelsErrored = true;
    }
    const joins = this.channels.map((channel) => [channel, channel.joinRef()]);
    joins.forEach(([channel, joinRef]) => {
      if (channel.joinRef() !== joinRef) {
        return;
      }
      if (connection && (erroredBefore || !connection.isCurrent()) && !connection.carried(channel, joinRef)) {
        return;
      }
      if (!(channel.isErrored() || channel.isLeaving() || channel.isClosed())) {
        channel.trigger(CHANNEL_EVENTS.error, { source: "transport", reason });
      }
    });
  }
  /**
   * @returns {string}
   */
  connectionState() {
    switch (this.conn && this.conn.readyState) {
      case SOCKET_STATES.connecting:
        return "connecting";
      case SOCKET_STATES.open:
        return "open";
      case SOCKET_STATES.closing:
        return "closing";
      default:
        return "closed";
    }
  }
  /**
   * @returns {boolean}
   */
  isConnected() {
    return this.connectionState() === "open";
  }
  /**
   * @private
   *
   * @param {Channel}
   */
  remove(channel) {
    this.off(channel.stateChangeRefs);
    this.channels = this.channels.filter((c) => c !== channel);
  }
  /**
   * Removes `onOpen`, `onClose`, `onError,` and `onMessage` registrations.
   *
   * @param {refs} - list of refs returned by calls to
   *                 `onOpen`, `onClose`, `onError,` and `onMessage`
   */
  off(refs) {
    for (let key in this.stateChangeCallbacks) {
      this.stateChangeCallbacks[key] = this.stateChangeCallbacks[key].filter(([ref]) => {
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
  channel(topic, chanParams = {}) {
    let chan = new Channel(topic, chanParams, this);
    this.channels.push(chan);
    return chan;
  }
  /**
   * @param {Object} data
   * @param {Channel} [channel] - The channel the push belongs to, if any
   */
  push(data, channel) {
    if (this.hasLogger()) {
      let { topic, event, payload, ref, join_ref } = data;
      this.log("push", `${topic} ${event} (${join_ref}, ${ref})`, payload);
    }
    if (this.isConnected()) {
      this.send(data, channel);
    } else {
      this.sendBuffer.push(() => {
        if (!this.isOutdated(data, channel)) {
          this.send(data, channel);
        }
      });
    }
  }
  /**
   * @private
   */
  send(data, channel) {
    const connection = this.connection;
    if (channel && data.event === CHANNEL_EVENTS.join) {
      connection.joins.set(channel, data.join_ref);
    }
    this.encode(data, (result) => {
      if (!connection.isCurrent() || !connection.isOpen()) {
        return;
      }
      if (data.event !== CHANNEL_EVENTS.leave && this.isOutdated(data, channel)) {
        return;
      }
      connection.transport.send(result);
    });
  }
  /**
   * @private
   *
   * Whether the push was made for an earlier join of its channel, or the channel left since.
   */
  isOutdated(data, channel) {
    return !!channel && (data.join_ref !== channel.joinRef() || channel.isClosed());
  }
  /**
   * Return the next message ref, accounting for overflows
   * @returns {string}
   */
  makeRef() {
    let newRef = this.ref + 1;
    if (newRef === this.ref) {
      this.ref = 0;
    } else {
      this.ref = newRef;
    }
    return this.ref.toString();
  }
  sendHeartbeat() {
    if (this.pendingHeartbeatRef && !this.isConnected()) {
      return;
    }
    this.pendingHeartbeatRef = this.makeRef();
    this.push({ topic: "phoenix", event: "heartbeat", payload: {}, ref: this.pendingHeartbeatRef });
    this.heartbeatTimeoutTimer = setTimeout(() => this.heartbeatTimeout(), this.heartbeatIntervalMs);
  }
  flushSendBuffer() {
    if (this.isConnected() && this.sendBuffer.length > 0) {
      this.sendBuffer.forEach((callback) => callback());
      this.sendBuffer = [];
    }
  }
  onConnMessage(rawMessage) {
    const connection = this.connection;
    const wasOpen = connection && connection.isOpen();
    this.decode(rawMessage.data, (msg) => {
      if (connection !== this.connection || wasOpen && !connection.isOpen()) {
        return;
      }
      let { topic, event, payload, ref, join_ref } = msg;
      if (ref && ref === this.pendingHeartbeatRef) {
        this.clearHeartbeats();
        this.heartbeatTimer = setTimeout(() => this.sendHeartbeat(), this.heartbeatIntervalMs);
      }
      if (this.hasLogger()) this.log("receive", `${payload.status || ""} ${topic} ${event} ${ref && "(" + ref + ")" || ""}`, payload);
      const channels = this.channels;
      for (let i = 0; i < channels.length; i++) {
        const channel = channels[i];
        if (!channel.isMember(topic, event, payload, join_ref)) {
          continue;
        }
        channel.trigger(event, payload, ref, join_ref);
      }
      const callbacks = this.stateChangeCallbacks.message;
      for (let i = 0; i < callbacks.length; i++) {
        let [, callback] = callbacks[i];
        callback(msg);
      }
      const ping = ref && connection.pings.get(ref);
      if (ping) {
        connection.pings.delete(ref);
        ping();
      }
    });
  }
  leaveOpenTopic(topic) {
    let dupChannel = this.channels.find((c) => c.topic === topic && (c.isJoined() || c.isJoining()));
    if (dupChannel) {
      if (this.hasLogger()) this.log("transport", `leaving duplicate topic "${topic}"`);
      dupChannel.leave();
    }
  }
};
//# sourceMappingURL=phoenix.cjs.js.map
