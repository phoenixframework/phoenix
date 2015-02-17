(function webpackUniversalModuleDefinition(root, factory) {
	if(typeof exports === 'object' && typeof module === 'object')
		module.exports = factory();
	else if(typeof define === 'function' && define.amd)
		define(factory);
	else if(typeof exports === 'object')
		exports["Phoenix"] = factory();
	else
		root["Phoenix"] = factory();
})(this, function() {
return /******/ (function(modules) { // webpackBootstrap
/******/ 	// The module cache
/******/ 	var installedModules = {};
/******/
/******/ 	// The require function
/******/ 	function __webpack_require__(moduleId) {
/******/
/******/ 		// Check if module is in cache
/******/ 		if(installedModules[moduleId])
/******/ 			return installedModules[moduleId].exports;
/******/
/******/ 		// Create a new module (and put it into the cache)
/******/ 		var module = installedModules[moduleId] = {
/******/ 			exports: {},
/******/ 			id: moduleId,
/******/ 			loaded: false
/******/ 		};
/******/
/******/ 		// Execute the module function
/******/ 		modules[moduleId].call(module.exports, module, module.exports, __webpack_require__);
/******/
/******/ 		// Flag the module as loaded
/******/ 		module.loaded = true;
/******/
/******/ 		// Return the exports of the module
/******/ 		return module.exports;
/******/ 	}
/******/
/******/
/******/ 	// expose the modules object (__webpack_modules__)
/******/ 	__webpack_require__.m = modules;
/******/
/******/ 	// expose the module cache
/******/ 	__webpack_require__.c = installedModules;
/******/
/******/ 	// __webpack_public_path__
/******/ 	__webpack_require__.p = "";
/******/
/******/ 	// Load entry module and return exports
/******/ 	return __webpack_require__(0);
/******/ })
/************************************************************************/
/******/ ([
/* 0 */
/***/ function(module, exports, __webpack_require__) {

	"use strict";

	var _prototypeProperties = function (child, staticProps, instanceProps) { if (staticProps) Object.defineProperties(child, staticProps); if (instanceProps) Object.defineProperties(child.prototype, instanceProps); };

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

	  _prototypeProperties(Channel, null, {
	    reset: {
	      value: function reset() {
	        this.bindings = [];
	      },
	      writable: true,
	      configurable: true
	    },
	    on: {
	      value: function on(event, callback) {
	        this.bindings.push({ event: event, callback: callback });
	      },
	      writable: true,
	      configurable: true
	    },
	    isMember: {
	      value: function isMember(topic) {
	        return this.topic === topic;
	      },
	      writable: true,
	      configurable: true
	    },
	    off: {
	      value: function off(event) {
	        this.bindings = this.bindings.filter(function (bind) {
	          return bind.event !== event;
	        });
	      },
	      writable: true,
	      configurable: true
	    },
	    trigger: {
	      value: function trigger(triggerEvent, msg) {
	        this.bindings.filter(function (bind) {
	          return bind.event === triggerEvent;
	        }).map(function (bind) {
	          return bind.callback(msg);
	        });
	      },
	      writable: true,
	      configurable: true
	    },
	    send: {
	      value: function send(event, payload) {
	        this.socket.send({ topic: this.topic, event: event, payload: payload });
	      },
	      writable: true,
	      configurable: true
	    },
	    leave: {
	      value: function leave() {
	        var message = arguments[0] === undefined ? {} : arguments[0];
	        this.socket.leave(this.topic, message);
	        this.reset();
	      },
	      writable: true,
	      configurable: true
	    }
	  });

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

	    this.transport = opts.transport || WebSocket || LongPoller;
	    this.heartbeatIntervalMs = opts.heartbeatIntervalMs || this.heartbeatIntervalMs;
	    this.logger = opts.logger || function () {}; // noop
	    this.endPoint = this.expandEndpoint(endPoint);
	    this.resetBufferTimer();
	    this.reconnect();
	  }

	  _prototypeProperties(Socket, null, {
	    protocol: {
	      value: function protocol() {
	        return location.protocol.match(/^https/) ? "wss" : "ws";
	      },
	      writable: true,
	      configurable: true
	    },
	    expandEndpoint: {
	      value: function expandEndpoint(endPoint) {
	        if (endPoint.charAt(0) !== "/") {
	          return endPoint;
	        }
	        if (endPoint.charAt(1) === "/") {
	          return "" + this.protocol() + ":" + endPoint;
	        }

	        return "" + this.protocol() + "://" + location.host + "" + endPoint;
	      },
	      writable: true,
	      configurable: true
	    },
	    close: {
	      value: function close(callback, code, reason) {
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
	      },
	      writable: true,
	      configurable: true
	    },
	    reconnect: {
	      value: function reconnect() {
	        var _this = this;
	        this.close(function () {
	          _this.conn = new _this.transport(_this.endPoint);
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
	      },
	      writable: true,
	      configurable: true
	    },
	    resetBufferTimer: {
	      value: function resetBufferTimer() {
	        var _this = this;
	        clearTimeout(this.sendBufferTimer);
	        this.sendBufferTimer = setTimeout(function () {
	          return _this.flushSendBuffer();
	        }, this.flushEveryMs);
	      },
	      writable: true,
	      configurable: true
	    },
	    log: {

	      // Logs the message. Override `this.logger` for specialized logging. noops by default
	      value: function log(msg) {
	        this.logger(msg);
	      },
	      writable: true,
	      configurable: true
	    },
	    onOpen: {

	      // Registers callbacks for connection state change events
	      //
	      // Examples
	      //
	      //    socket.onError (error) -> alert("An error occurred")
	      //
	      value: function onOpen(callback) {
	        this.stateChangeCallbacks.open.push(callback);
	      },
	      writable: true,
	      configurable: true
	    },
	    onClose: {
	      value: function onClose(callback) {
	        this.stateChangeCallbacks.close.push(callback);
	      },
	      writable: true,
	      configurable: true
	    },
	    onError: {
	      value: function onError(callback) {
	        this.stateChangeCallbacks.error.push(callback);
	      },
	      writable: true,
	      configurable: true
	    },
	    onMessage: {
	      value: function onMessage(callback) {
	        this.stateChangeCallbacks.message.push(callback);
	      },
	      writable: true,
	      configurable: true
	    },
	    onConnOpen: {
	      value: function onConnOpen() {
	        var _this = this;
	        clearInterval(this.reconnectTimer);
	        if (!this.transport.skipHeartbeat) {
	          this.heartbeatTimer = setInterval(function () {
	            return _this.sendHeartbeat();
	          }, this.heartbeatIntervalMs);
	        }
	        this.rejoinAll();
	        this.stateChangeCallbacks.open.forEach(function (callback) {
	          return callback();
	        });
	      },
	      writable: true,
	      configurable: true
	    },
	    onConnClose: {
	      value: function onConnClose(event) {
	        var _this = this;
	        this.log("WS close:");
	        this.log(event);
	        clearInterval(this.reconnectTimer);
	        clearInterval(this.heartbeatTimer);
	        this.reconnectTimer = setInterval(function () {
	          return _this.reconnect();
	        }, this.reconnectAfterMs);
	        this.stateChangeCallbacks.close.forEach(function (callback) {
	          return callback(event);
	        });
	      },
	      writable: true,
	      configurable: true
	    },
	    onConnError: {
	      value: function onConnError(error) {
	        this.log("WS error:");
	        this.log(error);
	        this.stateChangeCallbacks.error.forEach(function (callback) {
	          return callback(error);
	        });
	      },
	      writable: true,
	      configurable: true
	    },
	    connectionState: {
	      value: function connectionState() {
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
	      },
	      writable: true,
	      configurable: true
	    },
	    isConnected: {
	      value: function isConnected() {
	        return this.connectionState() === "open";
	      },
	      writable: true,
	      configurable: true
	    },
	    rejoinAll: {
	      value: function rejoinAll() {
	        var _this = this;
	        this.channels.forEach(function (chan) {
	          return _this.rejoin(chan);
	        });
	      },
	      writable: true,
	      configurable: true
	    },
	    rejoin: {
	      value: function rejoin(chan) {
	        chan.reset();
	        this.send({ topic: chan.topic, event: "join", payload: chan.message });
	        chan.callback(chan);
	      },
	      writable: true,
	      configurable: true
	    },
	    join: {
	      value: function join(topic, message, callback) {
	        var chan = new Channel(topic, message, callback, this);
	        this.channels.push(chan);
	        if (this.isConnected()) {
	          this.rejoin(chan);
	        }
	      },
	      writable: true,
	      configurable: true
	    },
	    leave: {
	      value: function leave(topic) {
	        var message = arguments[1] === undefined ? {} : arguments[1];
	        this.send({ topic: topic, event: "leave", payload: message });
	        this.channels = this.channels.filter(function (c) {
	          return !c.isMember(topic);
	        });
	      },
	      writable: true,
	      configurable: true
	    },
	    send: {
	      value: function send(data) {
	        var _this = this;
	        var callback = function () {
	          return _this.conn.send(JSON.stringify(data));
	        };
	        if (this.isConnected()) {
	          callback();
	        } else {
	          this.sendBuffer.push(callback);
	        }
	      },
	      writable: true,
	      configurable: true
	    },
	    sendHeartbeat: {
	      value: function sendHeartbeat() {
	        this.send({ topic: "phoenix", event: "heartbeat", payload: {} });
	      },
	      writable: true,
	      configurable: true
	    },
	    flushSendBuffer: {
	      value: function flushSendBuffer() {
	        if (this.isConnected() && this.sendBuffer.length > 0) {
	          this.sendBuffer.forEach(function (callback) {
	            return callback();
	          });
	          this.sendBuffer = [];
	        }
	        this.resetBufferTimer();
	      },
	      writable: true,
	      configurable: true
	    },
	    onConnMessage: {
	      value: function onConnMessage(rawMessage) {
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
	      },
	      writable: true,
	      configurable: true
	    }
	  });

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

	  _prototypeProperties(LongPoller, null, {
	    normalizeEndpoint: {
	      value: function normalizeEndpoint(endPoint) {
	        return endPoint.replace("ws://", "http://").replace("wss://", "https://");
	      },
	      writable: true,
	      configurable: true
	    },
	    endpointURL: {
	      value: function endpointURL() {
	        return this.pollEndpoint + ("?token=" + encodeURIComponent(this.token) + "&sig=" + encodeURIComponent(this.sig));
	      },
	      writable: true,
	      configurable: true
	    },
	    closeAndRetry: {
	      value: function closeAndRetry() {
	        this.close();
	        this.readyState = this.states.connecting;
	      },
	      writable: true,
	      configurable: true
	    },
	    ontimeout: {
	      value: function ontimeout() {
	        this.onerror("timeout");
	        this.closeAndRetry();
	      },
	      writable: true,
	      configurable: true
	    },
	    poll: {
	      value: function poll() {
	        var _this = this;
	        if (!(this.readyState === this.states.open || this.readyState === this.states.connecting)) {
	          return;
	        }

	        Ajax.request("GET", this.endpointURL(), "application/json", null, this.ontimeout.bind(this), function (status, resp) {
	          if (resp && resp !== "") {
	            var _JSON$parse = JSON.parse(resp);

	            var token = _JSON$parse.token;
	            var sig = _JSON$parse.sig;
	            var messages = _JSON$parse.messages;
	            _this.token = token;
	            _this.sig = sig;
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
	      },
	      writable: true,
	      configurable: true
	    },
	    send: {
	      value: function send(body) {
	        var _this = this;
	        Ajax.request("POST", this.endpointURL(), "application/json", body, this.onerror.bind(this, "timeout"), function (status, resp) {
	          if (status !== 200) {
	            _this.onerror(status);
	          }
	        });
	      },
	      writable: true,
	      configurable: true
	    },
	    close: {
	      value: function close(code, reason) {
	        this.readyState = this.states.closed;
	        this.onclose();
	      },
	      writable: true,
	      configurable: true
	    }
	  });

	  return LongPoller;
	})();
	var Ajax = exports.Ajax = {

	  states: { complete: 4 },

	  request: function (method, endPoint, accept, body, ontimeout, callback) {
	    var _this = this;
	    var req = XMLHttpRequest ? new XMLHttpRequest() : // IE7+, Firefox, Chrome, Opera, Safari
	    new ActiveXObject("Microsoft.XMLHTTP"); // IE6, IE5
	    req.open(method, endPoint, true);
	    req.setRequestHeader("Content-type", accept);
	    req.onerror = function () {
	      callback && callback(500, null);
	    };
	    req.onreadystatechange = function () {
	      if (req.readyState === _this.states.complete && callback) {
	        callback(req.status, req.responseText);
	      }
	    };
	    if (ontimeout) {
	      req.ontimeout = ontimeout;
	    }

	    req.send(body);
	  }
	};

	// export for browser hack
	if (typeof window === "object") {
	  window.Phoenix = exports;
	}
	Object.defineProperty(exports, "__esModule", {
	  value: true
	});

/***/ }
/******/ ])
});
