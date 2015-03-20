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

var SOCKET_STATES = { connecting: 0, open: 1, closing: 2, closed: 3 };

var Channel = exports.Channel = (function () {
  function Channel(topic, message, callback, socket) {
    _classCallCheck(this, Channel);

    this.topic = topic;
    this.message = message;
    this.callback = callback;
    this.socket = socket;
    this.bindings = null;

    this.reset();
  }

  Channel.prototype.rejoin = function rejoin() {
    var _this = this;

    this.reset();
    this.onError(function (reason) {
      return _this.rejoin();
    });
    this.socket.send({ topic: this.topic, event: "join", payload: this.message });
    this.callback(this);
  };

  Channel.prototype.onClose = function onClose(callback) {
    this.on("chan:close", callback);
  };

  Channel.prototype.onError = function onError(callback) {
    var _this = this;

    this.on("chan:error", function (reason) {
      callback(reason);
      _this.trigger("chan:close", "error");
    });
  };

  Channel.prototype.reset = function reset() {
    this.bindings = [];
  };

  Channel.prototype.on = function on(event, callback) {
    this.bindings.push({ event: event, callback: callback });
  };

  Channel.prototype.isMember = function isMember(topic) {
    return this.topic === topic;
  };

  Channel.prototype.off = function off(event) {
    this.bindings = this.bindings.filter(function (bind) {
      return bind.event !== event;
    });
  };

  Channel.prototype.trigger = function trigger(triggerEvent, msg) {
    this.bindings.filter(function (bind) {
      return bind.event === triggerEvent;
    }).map(function (bind) {
      return bind.callback(msg);
    });
  };

  Channel.prototype.send = function send(event, payload) {
    this.socket.send({ topic: this.topic, event: event, payload: payload });
  };

  Channel.prototype.leave = function leave() {
    var message = arguments[0] === undefined ? {} : arguments[0];

    this.socket.leave(this.topic, message);
    this.reset();
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
  //   heartbeatIntervalMs - The millisecond interval to send a heartbeat message
  //   logger - The optional function for specialized logging, ie:
  //            `logger: (msg) -> console.log(msg)`
  //   longpoller_timeout - The maximum timeout of a long poll AJAX request.
  //                        Defaults to 20s (double the server long poll timer).
  //
  // For IE8 support use an ES5-shim (https://github.com/es-shims/es5-shim)
  //

  function Socket(endPoint) {
    var opts = arguments[1] === undefined ? {} : arguments[1];

    _classCallCheck(this, Socket);

    this.states = SOCKET_STATES;
    this.stateChangeCallbacks = { open: [], close: [], error: [], message: [] };
    this.flushEveryMs = 50;
    this.reconnectTimer = null;
    this.reconnectAfterMs = 5000;
    this.heartbeatIntervalMs = 30000;
    this.channels = [];
    this.sendBuffer = [];

    this.transport = opts.transport || window.WebSocket || LongPoller;
    this.heartbeatIntervalMs = opts.heartbeatIntervalMs || this.heartbeatIntervalMs;
    this.logger = opts.logger || function () {}; // noop
    this.longpoller_timeout = opts.longpoller_timeout || 20000;
    this.endPoint = this.expandEndpoint(endPoint);
    this.resetBufferTimer();
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

  Socket.prototype.resetBufferTimer = function resetBufferTimer() {
    var _this = this;

    clearTimeout(this.sendBufferTimer);
    this.sendBufferTimer = setTimeout(function () {
      return _this.flushSendBuffer();
    }, this.flushEveryMs);
  };

  // Logs the message. Override `this.logger` for specialized logging. noops by default

  Socket.prototype.log = function log(msg) {
    this.logger(msg);
  };

  // Registers callbacks for connection state change events
  //
  // Examples
  //
  //    socket.onError (error) -> alert("An error occurred")
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

    clearInterval(this.reconnectTimer);
    if (!this.conn.skipHeartbeat) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = setInterval(function () {
        return _this.sendHeartbeat();
      }, this.heartbeatIntervalMs);
    }
    this.rejoinAll();
    this.stateChangeCallbacks.open.forEach(function (callback) {
      return callback();
    });
  };

  Socket.prototype.onConnClose = function onConnClose(event) {
    var _this = this;

    this.log("WS close:");
    this.log(event);
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
    this.stateChangeCallbacks.error.forEach(function (callback) {
      return callback(error);
    });
  };

  Socket.prototype.connectionState = function connectionState() {
    switch (this.conn && this.conn.readyState) {
      case this.states.connecting:
        return "connecting";
      case this.states.open:
        return "open";
      case this.states.closing:
        return "closing";
      default:
        return "closed";
    }
  };

  Socket.prototype.isConnected = function isConnected() {
    return this.connectionState() === "open";
  };

  Socket.prototype.rejoinAll = function rejoinAll() {
    this.channels.forEach(function (chan) {
      return chan.rejoin();
    });
  };

  Socket.prototype.join = function join(topic, message, callback) {
    var chan = new Channel(topic, message, callback, this);
    this.channels.push(chan);
    if (this.isConnected()) {
      chan.rejoin();
    }
  };

  Socket.prototype.leave = function leave(topic) {
    var message = arguments[1] === undefined ? {} : arguments[1];

    this.send({ topic: topic, event: "leave", payload: message });
    this.channels = this.channels.filter(function (c) {
      return !c.isMember(topic);
    });
  };

  Socket.prototype.send = function send(data) {
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

  Socket.prototype.sendHeartbeat = function sendHeartbeat() {
    this.send({ topic: "phoenix", event: "heartbeat", payload: {} });
  };

  Socket.prototype.flushSendBuffer = function flushSendBuffer() {
    if (this.isConnected() && this.sendBuffer.length > 0) {
      this.sendBuffer.forEach(function (callback) {
        return callback();
      });
      this.sendBuffer = [];
    }
    this.resetBufferTimer();
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
    this.states = SOCKET_STATES;
    this.upgradeEndpoint = this.normalizeEndpoint(endPoint);
    this.pollEndpoint = this.upgradeEndpoint + (/\/$/.test(endPoint) ? "poll" : "/poll");
    this.readyState = this.states.connecting;

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
    this.readyState = this.states.connecting;
  };

  LongPoller.prototype.ontimeout = function ontimeout() {
    this.onerror("timeout");
    this.closeAndRetry();
  };

  LongPoller.prototype.poll = function poll() {
    var _this = this;

    if (!(this.readyState === this.states.open || this.readyState === this.states.connecting)) {
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
          _this.readyState = _this.states.open;
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
    this.readyState = this.states.closed;
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