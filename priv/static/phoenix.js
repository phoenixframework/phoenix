(function(/*! Brunch !*/) {
  'use strict';

  var globals = typeof window !== 'undefined' ? window : global;
  if (typeof globals.require === 'function') return;

  var modules = {};
  var cache = {};

  var has = function(object, name) {
    return ({}).hasOwnProperty.call(object, name);
  };

  var expand = function(root, name) {
    var results = [], parts, part;
    if (/^\.\.?(\/|$)/.test(name)) {
      parts = [root, name].join('/').split('/');
    } else {
      parts = name.split('/');
    }
    for (var i = 0, length = parts.length; i < length; i++) {
      part = parts[i];
      if (part === '..') {
        results.pop();
      } else if (part !== '.' && part !== '') {
        results.push(part);
      }
    }
    return results.join('/');
  };

  var dirname = function(path) {
    return path.split('/').slice(0, -1).join('/');
  };

  var localRequire = function(path) {
    return function(name) {
      var dir = dirname(path);
      var absolute = expand(dir, name);
      return globals.require(absolute, path);
    };
  };

  var initModule = function(name, definition) {
    var module = {id: name, exports: {}};
    cache[name] = module;
    definition(module.exports, localRequire(name), module);
    return module.exports;
  };

  var require = function(name, loaderPath) {
    var path = expand(name, '.');
    if (loaderPath == null) loaderPath = '/';

    if (has(cache, path)) return cache[path].exports;
    if (has(modules, path)) return initModule(path, modules[path]);

    var dirIndex = expand(path, './index');
    if (has(cache, dirIndex)) return cache[dirIndex].exports;
    if (has(modules, dirIndex)) return initModule(dirIndex, modules[dirIndex]);

    throw new Error('Cannot find module "' + name + '" from '+ '"' + loaderPath + '"');
  };

  var define = function(bundle, fn) {
    if (typeof bundle === 'object') {
      for (var key in bundle) {
        if (has(bundle, key)) {
          modules[key] = bundle[key];
        }
      }
    } else {
      modules[bundle] = fn;
    }
  };

  var list = function() {
    var result = [];
    for (var item in modules) {
      if (has(modules, item)) {
        result.push(item);
      }
    }
    return result;
  };

  globals.require = require;
  globals.require.define = define;
  globals.require.register = define;
  globals.require.list = list;
  globals.require.brunch = true;
})();
require.define({'phoenix': function(exports, require, module){ "use strict";

var _classCallCheck = function (instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } };

// Phoenix Channels JavaScript client
//
// ## Socket Connection
//
// A single connection is established to the server and
// channels are mulitplexed over the connection.
// Connect to the server using the `Socket` class:
//
//     let socket = new Socket("/ws")
//     socket.connect()
//
// The `Socket` constructor takes the mount point of the socket
// as well as options that can be found in the Socket docs,
// such as configuring the `LongPoller` transport, and heartbeat.
//
//
// ## Channels
//
// Channels are isolated, concurrent processes on the server that
// subscribe to topics and broker events between the client and server.
// To join a channel, you must provide the topic, and channel params for
// authorization. Here's an example chat room example where `"new_msg"`
// events are listened for, messages are pushed to the server, and
// the channel is joined with ok/error matches, and `after` hook:
//
//     let chan = socket.chan("rooms:123", {token: roomToken})
//     chan.on("new_msg", msg => console.log("Got message", msg) )
//     $input.onEnter( e => {
//       chan.push("new_msg", {body: e.target.val})
//           .receive("ok", (message) => console.log("created message", message) )
//           .receive("error", (reasons) => console.log("create failed", reasons) )
//           .after(10000, () => console.log("Networking issue. Still waiting...") )
//     })
//     chan.join()
//         .receive("ok", ({messages}) => console.log("catching up", messages) )
//         .receive("error", ({reason}) => console.log("failed join", reason) )
//         .after(10000, () => console.log("Networking issue. Still waiting...") )
//
//
// ## Joining
//
// Joining a channel with `chan.join(topic, params)`, binds the params to
// `chan.params`. Subsequent rejoins will send up the modified params for
// updating authorization params, or passing up last_message_id information.
// Successful joins receive an "ok" status, while unsuccessful joins
// receive "error".
//
//
// ## Pushing Messages
//
// From the prevoius example, we can see that pushing messages to the server
// can be done with `chan.push(eventName, payload)` and we can optionally
// receive responses from the push. Additionally, we can use
// `after(millsec, callback)` to abort waiting for our `receive` hooks and
// take action after some period of waiting.
//
//
// ## Socket Hooks
//
// Lifecycle events of the multiplexed connection can be hooked into via
// `socket.onError()` and `socket.onClose()` events, ie:
//
//     socket.onError( () => console.log("there was an error with the connection!") )
//     socket.onClose( () => console.log("the connection dropped") )
//
//
// ## Channel Hooks
//
// For each joined channel, you can bind to `onError` and `onClose` events
// to monitor the channel lifecycle, ie:
//
//     chan.onError( () => console.log("there was an error!") )
//     chan.onClose( () => console.log("the channel has gone away gracefully") )
//
// ### onError hooks
//
// `onError` hooks are invoked if the socket connection drops, or the channel
// crashes on the server. In either case, a channel rejoin is attemtped
// automatically in an exponential backoff manner.
//
// ### onClose hooks
//
// `onClose` hooks are invoked only in two cases. 1) the channel explicitly
// closed on the server, or 2). The client explicitly closed, by calling
// `chan.leave()`
//

var SOCKET_STATES = { connecting: 0, open: 1, closing: 2, closed: 3 };
var CHAN_STATES = {
  closed: "closed",
  errored: "errored",
  joined: "joined",
  joining: "joining" };
var CHAN_EVENTS = {
  close: "phx_close",
  error: "phx_error",
  join: "phx_join",
  reply: "phx_reply",
  leave: "phx_leave"
};

var Push = (function () {

  // Initializes the Push
  //
  // chan - The Channel
  // event - The event, ie `"phx_join"`
  // payload - The payload, ie `{user_id: 123}`
  //

  function Push(chan, event, payload) {
    _classCallCheck(this, Push);

    this.chan = chan;
    this.event = event;
    this.payload = payload || {};
    this.receivedResp = null;
    this.afterHook = null;
    this.recHooks = [];
    this.sent = false;
  }

  Push.prototype.send = function send() {
    var _this = this;

    var ref = this.chan.socket.makeRef();
    this.refEvent = this.chan.replyEventName(ref);
    this.receivedResp = null;
    this.sent = false;

    this.chan.on(this.refEvent, function (payload) {
      _this.receivedResp = payload;
      _this.matchReceive(payload);
      _this.cancelRefEvent();
      _this.cancelAfter();
    });

    this.startAfter();
    this.sent = true;
    this.chan.socket.push({
      topic: this.chan.topic,
      event: this.event,
      payload: this.payload,
      ref: ref
    });
  };

  Push.prototype.receive = function receive(status, callback) {
    if (this.receivedResp && this.receivedResp.status === status) {
      callback(this.receivedResp.response);
    }

    this.recHooks.push({ status: status, callback: callback });
    return this;
  };

  Push.prototype.after = function after(ms, callback) {
    if (this.afterHook) {
      throw "only a single after hook can be applied to a push";
    }
    var timer = null;
    if (this.sent) {
      timer = setTimeout(callback, ms);
    }
    this.afterHook = { ms: ms, callback: callback, timer: timer };
    return this;
  };

  // private

  Push.prototype.matchReceive = function matchReceive(_ref) {
    var status = _ref.status;
    var response = _ref.response;
    var ref = _ref.ref;

    this.recHooks.filter(function (h) {
      return h.status === status;
    }).forEach(function (h) {
      return h.callback(response);
    });
  };

  Push.prototype.cancelRefEvent = function cancelRefEvent() {
    this.chan.off(this.refEvent);
  };

  Push.prototype.cancelAfter = function cancelAfter() {
    if (!this.afterHook) {
      return;
    }
    clearTimeout(this.afterHook.timer);
    this.afterHook.timer = null;
  };

  Push.prototype.startAfter = function startAfter() {
    var _this = this;

    if (!this.afterHook) {
      return;
    }
    var callback = function () {
      _this.cancelRefEvent();
      _this.afterHook.callback();
    };
    this.afterHook.timer = setTimeout(callback, this.afterHook.ms);
  };

  return Push;
})();

var Channel = exports.Channel = (function () {
  function Channel(topic, params, socket) {
    var _this = this;

    _classCallCheck(this, Channel);

    this.state = CHAN_STATES.closed;
    this.topic = topic;
    this.params = params || {};
    this.socket = socket;
    this.bindings = [];
    this.joinedOnce = false;
    this.joinPush = new Push(this, CHAN_EVENTS.join, this.params);
    this.pushBuffer = [];

    this.joinPush.receive("ok", function () {
      _this.state = CHAN_STATES.joined;
    });
    this.onClose(function () {
      _this.state = CHAN_STATES.closed;
      _this.socket.remove(_this);
    });
    this.onError(function (reason) {
      _this.state = CHAN_STATES.errored;
      setTimeout(function () {
        return _this.rejoinUntilConnected();
      }, _this.socket.reconnectAfterMs);
    });
    this.on(CHAN_EVENTS.reply, function (payload) {
      _this.trigger(_this.replyEventName(payload.ref), payload);
    });
  }

  Channel.prototype.rejoinUntilConnected = function rejoinUntilConnected() {
    var _this = this;

    if (this.state !== CHAN_STATES.errored) {
      return;
    }
    if (this.socket.isConnected()) {
      this.rejoin();
    } else {
      setTimeout(function () {
        return _this.rejoinUntilConnected();
      }, this.socket.reconnectAfterMs);
    }
  };

  Channel.prototype.join = function join() {
    if (this.joinedOnce) {
      throw "tried to join mulitple times. 'join' can only be called a singe time per channel instance";
    } else {
      this.joinedOnce = true;
    }
    this.sendJoin();
    return this.joinPush;
  };

  Channel.prototype.onClose = function onClose(callback) {
    this.on(CHAN_EVENTS.close, callback);
  };

  Channel.prototype.onError = function onError(callback) {
    this.on(CHAN_EVENTS.error, function (reason) {
      return callback(reason);
    });
  };

  Channel.prototype.on = function on(event, callback) {
    this.bindings.push({ event: event, callback: callback });
  };

  Channel.prototype.off = function off(event) {
    this.bindings = this.bindings.filter(function (bind) {
      return bind.event !== event;
    });
  };

  Channel.prototype.canPush = function canPush() {
    return this.socket.isConnected() && this.state === CHAN_STATES.joined;
  };

  Channel.prototype.push = function push(event, payload) {
    if (!this.joinedOnce) {
      throw "tried to push '" + event + "' to '" + this.topic + "' before joining. Use chan.join() before pushing events";
    }
    var pushEvent = new Push(this, event, payload);
    if (this.canPush()) {
      pushEvent.send();
    } else {
      this.pushBuffer.push(pushEvent);
    }

    return pushEvent;
  };

  // Leaves the channel
  //
  // Unsubscribes from server events, and
  // instructs channel to terminate on server
  //
  // Triggers onClose() hooks
  //
  // To receive leave acknowledgements, use the a `receive`
  // hook to bind to the server ack, ie:
  //
  //     chan.leave().receive("ok", () => alert("left!") )
  //

  Channel.prototype.leave = function leave() {
    var _this = this;

    return this.push(CHAN_EVENTS.leave).receive("ok", function () {
      _this.trigger(CHAN_EVENTS.close, "leave");
    });
  };

  // private

  Channel.prototype.isMember = function isMember(topic) {
    return this.topic === topic;
  };

  Channel.prototype.sendJoin = function sendJoin() {
    this.state = CHAN_STATES.joining;
    this.joinPush.send();
  };

  Channel.prototype.rejoin = function rejoin() {
    this.sendJoin();
    this.pushBuffer.forEach(function (pushEvent) {
      return pushEvent.send();
    });
    this.pushBuffer = [];
  };

  Channel.prototype.trigger = function trigger(triggerEvent, msg) {
    this.bindings.filter(function (bind) {
      return bind.event === triggerEvent;
    }).map(function (bind) {
      return bind.callback(msg);
    });
  };

  Channel.prototype.replyEventName = function replyEventName(ref) {
    return "chan_reply_" + ref;
  };

  return Channel;
})();

var Socket = exports.Socket = (function () {

  // Initializes the Socket
  //
  // endPoint - The string WebSocket endpoint, ie, "ws://example.com/ws",
  //                                               "wss://example.com"
  //                                               "/ws" (inherited host & protocol)
  // opts - Optional configuration
  //   transport - The Websocket Transport, ie WebSocket, Phoenix.LongPoller.
  //               Defaults to WebSocket with automatic LongPoller fallback.
  //   heartbeatIntervalMs - The millisec interval to send a heartbeat message
  //   reconnectAfterMs - The millisec interval to reconnect after connection loss
  //   logger - The optional function for specialized logging, ie:
  //            `logger: function(msg){ console.log(msg) }`
  //   longpoller_timeout - The maximum timeout of a long poll AJAX request.
  //                        Defaults to 20s (double the server long poll timer).
  //
  // For IE8 support use an ES5-shim (https://github.com/es-shims/es5-shim)
  //

  function Socket(endPoint) {
    var opts = arguments[1] === undefined ? {} : arguments[1];

    _classCallCheck(this, Socket);

    this.stateChangeCallbacks = { open: [], close: [], error: [], message: [] };
    this.reconnectTimer = null;
    this.channels = [];
    this.sendBuffer = [];
    this.ref = 0;
    this.transport = opts.transport || window.WebSocket || LongPoller;
    this.heartbeatIntervalMs = opts.heartbeatIntervalMs || 30000;
    this.reconnectAfterMs = opts.reconnectAfterMs || 5000;
    this.logger = opts.logger || function () {}; // noop
    this.longpoller_timeout = opts.longpoller_timeout || 20000;
    this.endPoint = this.expandEndpoint(endPoint);
  }

  Socket.prototype.protocol = function protocol() {
    return location.protocol.match(/^https/) ? "wss" : "ws";
  };

  Socket.prototype.expandEndpoint = function expandEndpoint(endPoint) {
    if (endPoint.charAt(0) !== "/") {
      return endPoint;
    }
    if (endPoint.charAt(1) === "/") {
      return "" + this.protocol() + ":" + endPoint;
    }

    return "" + this.protocol() + "://" + location.host + "" + endPoint;
  };

  Socket.prototype.disconnect = function disconnect(callback, code, reason) {
    if (this.conn) {
      this.conn.onclose = function () {}; // noop
      if (code) {
        this.conn.close(code, reason || "");
      } else {
        this.conn.close();
      }
      this.conn = null;
    }
    callback && callback();
  };

  Socket.prototype.connect = function connect() {
    var _this = this;

    this.disconnect(function () {
      _this.conn = new _this.transport(_this.endPoint);
      _this.conn.timeout = _this.longpoller_timeout;
      _this.conn.onopen = function () {
        return _this.onConnOpen();
      };
      _this.conn.onerror = function (error) {
        return _this.onConnError(error);
      };
      _this.conn.onmessage = function (event) {
        return _this.onConnMessage(event);
      };
      _this.conn.onclose = function (event) {
        return _this.onConnClose(event);
      };
    });
  };

  // Logs the message. Override `this.logger` for specialized logging. noops by default

  Socket.prototype.log = function log(msg) {
    this.logger(msg);
  };

  // Registers callbacks for connection state change events
  //
  // Examples
  //
  //    socket.onError(function(error){ alert("An error occurred") })
  //

  Socket.prototype.onOpen = function onOpen(callback) {
    this.stateChangeCallbacks.open.push(callback);
  };

  Socket.prototype.onClose = function onClose(callback) {
    this.stateChangeCallbacks.close.push(callback);
  };

  Socket.prototype.onError = function onError(callback) {
    this.stateChangeCallbacks.error.push(callback);
  };

  Socket.prototype.onMessage = function onMessage(callback) {
    this.stateChangeCallbacks.message.push(callback);
  };

  Socket.prototype.onConnOpen = function onConnOpen() {
    var _this = this;

    this.flushSendBuffer();
    clearInterval(this.reconnectTimer);
    if (!this.conn.skipHeartbeat) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = setInterval(function () {
        return _this.sendHeartbeat();
      }, this.heartbeatIntervalMs);
    }
    this.stateChangeCallbacks.open.forEach(function (callback) {
      return callback();
    });
  };

  Socket.prototype.onConnClose = function onConnClose(event) {
    var _this = this;

    this.log("WS close:");
    this.log(event);
    this.triggerChanError();
    clearInterval(this.reconnectTimer);
    clearInterval(this.heartbeatTimer);
    this.reconnectTimer = setInterval(function () {
      return _this.connect();
    }, this.reconnectAfterMs);
    this.stateChangeCallbacks.close.forEach(function (callback) {
      return callback(event);
    });
  };

  Socket.prototype.onConnError = function onConnError(error) {
    this.log("WS error:");
    this.log(error);
    this.triggerChanError();
    this.stateChangeCallbacks.error.forEach(function (callback) {
      return callback(error);
    });
  };

  Socket.prototype.triggerChanError = function triggerChanError() {
    this.channels.forEach(function (chan) {
      return chan.trigger(CHAN_EVENTS.error);
    });
  };

  Socket.prototype.connectionState = function connectionState() {
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
  };

  Socket.prototype.isConnected = function isConnected() {
    return this.connectionState() === "open";
  };

  Socket.prototype.remove = function remove(chan) {
    this.channels = this.channels.filter(function (c) {
      return !c.isMember(chan.topic);
    });
  };

  Socket.prototype.chan = function chan(topic, params) {
    var chan = new Channel(topic, params, this);
    this.channels.push(chan);
    return chan;
  };

  Socket.prototype.push = function push(data) {
    var _this = this;

    var callback = function () {
      return _this.conn.send(JSON.stringify(data));
    };
    if (this.isConnected()) {
      callback();
    } else {
      this.sendBuffer.push(callback);
    }
  };

  // Return the next message ref, accounting for overflows

  Socket.prototype.makeRef = function makeRef() {
    var newRef = this.ref + 1;
    if (newRef === this.ref) {
      this.ref = 0;
    } else {
      this.ref = newRef;
    }

    return this.ref.toString();
  };

  Socket.prototype.sendHeartbeat = function sendHeartbeat() {
    this.push({ topic: "phoenix", event: "heartbeat", payload: {}, ref: this.makeRef() });
  };

  Socket.prototype.flushSendBuffer = function flushSendBuffer() {
    if (this.isConnected() && this.sendBuffer.length > 0) {
      this.sendBuffer.forEach(function (callback) {
        return callback();
      });
      this.sendBuffer = [];
    }
  };

  Socket.prototype.onConnMessage = function onConnMessage(rawMessage) {
    this.log("message received:");
    this.log(rawMessage);

    var _JSON$parse = JSON.parse(rawMessage.data);

    var topic = _JSON$parse.topic;
    var event = _JSON$parse.event;
    var payload = _JSON$parse.payload;

    this.channels.filter(function (chan) {
      return chan.isMember(topic);
    }).forEach(function (chan) {
      return chan.trigger(event, payload);
    });
    this.stateChangeCallbacks.message.forEach(function (callback) {
      callback(topic, event, payload);
    });
  };

  return Socket;
})();

var LongPoller = exports.LongPoller = (function () {
  function LongPoller(endPoint) {
    _classCallCheck(this, LongPoller);

    this.retryInMs = 5000;
    this.endPoint = null;
    this.token = null;
    this.sig = null;
    this.skipHeartbeat = true;
    this.onopen = function () {}; // noop
    this.onerror = function () {}; // noop
    this.onmessage = function () {}; // noop
    this.onclose = function () {}; // noop
    this.upgradeEndpoint = this.normalizeEndpoint(endPoint);
    this.pollEndpoint = this.upgradeEndpoint + (/\/$/.test(endPoint) ? "poll" : "/poll");
    this.readyState = SOCKET_STATES.connecting;

    this.poll();
  }

  LongPoller.prototype.normalizeEndpoint = function normalizeEndpoint(endPoint) {
    return endPoint.replace("ws://", "http://").replace("wss://", "https://");
  };

  LongPoller.prototype.endpointURL = function endpointURL() {
    return this.pollEndpoint + ("?token=" + encodeURIComponent(this.token) + "&sig=" + encodeURIComponent(this.sig));
  };

  LongPoller.prototype.closeAndRetry = function closeAndRetry() {
    this.close();
    this.readyState = SOCKET_STATES.connecting;
  };

  LongPoller.prototype.ontimeout = function ontimeout() {
    this.onerror("timeout");
    this.closeAndRetry();
  };

  LongPoller.prototype.poll = function poll() {
    var _this = this;

    if (!(this.readyState === SOCKET_STATES.open || this.readyState === SOCKET_STATES.connecting)) {
      return;
    }

    Ajax.request("GET", this.endpointURL(), "application/json", null, this.timeout, this.ontimeout.bind(this), function (resp) {
      if (resp) {
        var status = resp.status;
        var token = resp.token;
        var sig = resp.sig;
        var messages = resp.messages;

        _this.token = token;
        _this.sig = sig;
      } else {
        var status = 0;
      }

      switch (status) {
        case 200:
          messages.forEach(function (msg) {
            return _this.onmessage({ data: JSON.stringify(msg) });
          });
          _this.poll();
          break;
        case 204:
          _this.poll();
          break;
        case 410:
          _this.readyState = SOCKET_STATES.open;
          _this.onopen();
          _this.poll();
          break;
        case 0:
        case 500:
          _this.onerror();
          _this.closeAndRetry();
          break;
        default:
          throw "unhandled poll status " + status;
      }
    });
  };

  LongPoller.prototype.send = function send(body) {
    var _this = this;

    Ajax.request("POST", this.endpointURL(), "application/json", body, this.timeout, this.onerror.bind(this, "timeout"), function (resp) {
      if (!resp || resp.status !== 200) {
        _this.onerror(status);
        _this.closeAndRetry();
      }
    });
  };

  LongPoller.prototype.close = function close(code, reason) {
    this.readyState = SOCKET_STATES.closed;
    this.onclose();
  };

  return LongPoller;
})();

var Ajax = exports.Ajax = (function () {
  function Ajax() {
    _classCallCheck(this, Ajax);
  }

  Ajax.request = function request(method, endPoint, accept, body, timeout, ontimeout, callback) {
    if (window.XDomainRequest) {
      var req = new XDomainRequest(); // IE8, IE9
      this.xdomainRequest(req, method, endPoint, body, timeout, ontimeout, callback);
    } else {
      var req = window.XMLHttpRequest ? new XMLHttpRequest() : // IE7+, Firefox, Chrome, Opera, Safari
      new ActiveXObject("Microsoft.XMLHTTP"); // IE6, IE5
      this.xhrRequest(req, method, endPoint, accept, body, timeout, ontimeout, callback);
    }
  };

  Ajax.xdomainRequest = function xdomainRequest(req, method, endPoint, body, timeout, ontimeout, callback) {
    var _this = this;

    req.timeout = timeout;
    req.open(method, endPoint);
    req.onload = function () {
      var response = _this.parseJSON(req.responseText);
      callback && callback(response);
    };
    if (ontimeout) {
      req.ontimeout = ontimeout;
    }

    // Work around bug in IE9 that requires an attached onprogress handler
    req.onprogress = function () {};

    req.send(body);
  };

  Ajax.xhrRequest = function xhrRequest(req, method, endPoint, accept, body, timeout, ontimeout, callback) {
    var _this = this;

    req.timeout = timeout;
    req.open(method, endPoint, true);
    req.setRequestHeader("Content-Type", accept);
    req.onerror = function () {
      callback && callback(null);
    };
    req.onreadystatechange = function () {
      if (req.readyState === _this.states.complete && callback) {
        var response = _this.parseJSON(req.responseText);
        callback(response);
      }
    };
    if (ontimeout) {
      req.ontimeout = ontimeout;
    }

    req.send(body);
  };

  Ajax.parseJSON = function parseJSON(resp) {
    return resp && resp !== "" ? JSON.parse(resp) : null;
  };

  return Ajax;
})();

Ajax.states = { complete: 4 };
exports.__esModule = true;
 }});
if(typeof(window) === 'object' && !window.Phoenix){ window.Phoenix = require('phoenix') };