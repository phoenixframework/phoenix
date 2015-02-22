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
"use strict";

var _prototypeProperties = function _prototypeProperties(child, staticProps, instanceProps) {
  if (staticProps) Object.defineProperties(child, staticProps);if (instanceProps) Object.defineProperties(child.prototype, instanceProps);
};

var _classCallCheck = function _classCallCheck(instance, Constructor) {
  if (!(instance instanceof Constructor)) {
    throw new TypeError("Cannot call a class as a function");
  }
};

(function (root, factory) {
  if (typeof define === "function" && define.amd) {
    return define(["phoenix"], factory);
  } else if (typeof exports === "object") {
    return factory(exports);
  } else {
    root.Phoenix = {};
    return factory.call(root, root.Phoenix);
  }
})(Function("return this")(), function (exports) {
  var root = this;
  var SOCKET_STATES = { connecting: 0, open: 1, closing: 2, closed: 3 };

  exports.Channel = (function () {
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

  exports.Socket = (function () {
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

      this.transport = opts.transport || root.WebSocket || exports.LongPoller;
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
          var chan = new exports.Channel(topic, message, callback, this);
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
          var callback = function callback() {
            return _this.conn.send(root.JSON.stringify(data));
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
          var _root$JSON$parse = root.JSON.parse(rawMessage.data);

          var topic = _root$JSON$parse.topic;
          var event = _root$JSON$parse.event;
          var payload = _root$JSON$parse.payload;
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

  exports.LongPoller = (function () {
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

          exports.Ajax.request("GET", this.endpointURL(), "application/json", null, this.ontimeout.bind(this), function (status, resp) {
            if (resp && resp !== "") {
              var _root$JSON$parse = root.JSON.parse(resp);

              var token = _root$JSON$parse.token;
              var sig = _root$JSON$parse.sig;
              var messages = _root$JSON$parse.messages;
              _this.token = token;
              _this.sig = sig;
            }
            switch (status) {
              case 200:
                messages.forEach(function (msg) {
                  return _this.onmessage({ data: root.JSON.stringify(msg) });
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
          exports.Ajax.request("POST", this.endpointURL(), "application/json", body, this.onerror.bind(this, "timeout"), function (status, resp) {
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

  exports.Ajax = {

    states: { complete: 4 },

    request: function request(method, endPoint, accept, body, ontimeout, callback) {
      var _this = this;
      var req = root.XMLHttpRequest ? new root.XMLHttpRequest() : // IE7+, Firefox, Chrome, Opera, Safari
      new root.ActiveXObject("Microsoft.XMLHTTP"); // IE6, IE5
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
});require.register("web/static/js/app", function(exports, require, module) {
"use strict";

// This is is your main ES6 application entry point});

;
//# sourceMappingURL=app.js.map