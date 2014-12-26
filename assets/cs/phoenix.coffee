((root, factory) ->
  if typeof define == "function" && define.amd
    define(["phoenix"], factory)
  else if typeof exports == "object"
    factory(exports)
  else
    factory((root.Phoenix = {}))
) this, (exports) ->
  root = this

  class exports.Channel

    bindings: null

    constructor: (@channel, @topic, @message, @callback, @socket) ->
      @reset()


    reset: -> @bindings = []

    on: (event, callback) -> @bindings.push({event, callback})

    isMember: (channel, topic) -> @channel is channel and @topic is topic

    off: (event) ->
      @bindings = (bind for bind in @bindings when bind.event isnt event)


    trigger: (triggerEvent, msg) ->
      callback(msg) for {event, callback} in @bindings when event is triggerEvent


    send: (event, message) -> @socket.send({@channel, @topic, event, message})

    leave: (message = {}) ->
      @socket.leave(@channel, @topic, message)
      @reset()



  class exports.Socket

    @states: {connecting: 0, open: 1, closing: 2, closed: 3}

    conn: null
    endPoint: null
    channels: null
    sendBuffer: null
    sendBufferTimer: null
    flushEveryMs: 50
    reconnectTimer: null
    reconnectAfterMs: 5000
    heartbeatIntervalMs: 30000
    stateChangeCallbacks: null
    transport: null

    # Initializes the Socket
    #
    # endPoint - The string WebSocket endpoint, ie, "ws://example.com/ws",
    #                                               "wss://example.com"
    #                                               "/ws" (inherited host & protocol)
    # opts - Optional configuration
    #   transport - The Websocket Transport, ie WebSocket, Phoenix.LongPoller.
    #               Defaults to WebSocket with automatic LongPoller fallback.
    #   heartbeatIntervalMs - The millisecond interval to send a heartbeat message
    #   logger - The optional function for specialized logging, ie:
    #            `logger: (msg) -> console.log(msg)`
    #
    constructor: (endPoint, opts = {}) ->
      @states = exports.Socket.states
      @transport = opts.transport ? root.WebSocket ? exports.LongPoller
      @heartbeatIntervalMs = opts.heartbeatIntervalMs ? @heartbeatIntervalMs
      @logger = opts.logger ? (-> ) # noop
      @endPoint = @expandEndpoint(endPoint)
      @channels = []
      @sendBuffer = []
      @stateChangeCallbacks = {open: [], close: [], error: [], message: []}
      @resetBufferTimer()
      @reconnect()


    protocol: -> if location.protocol.match(/^https/) then "wss" else "ws"

    expandEndpoint: (endPoint) ->
      return endPoint unless endPoint.charAt(0) is "/"
      return "#{@protocol()}:#{endPoint}" if endPoint.charAt(1) is "/"

      "#{@protocol()}://#{location.host}#{endPoint}"


    close: (callback, code, reason) ->
      if @conn?
        @conn.onclose = => #noop
        if code? then @conn.close(code, reason ? "") else @conn.close()
        @conn = null
      callback?()


    reconnect: ->
      @close =>
        @conn = new @transport(@endPoint)
        @conn.onopen = => @onConnOpen()
        @conn.onerror = (error) => @onConnError(error)
        @conn.onmessage = (event) =>  @onConnMessage(event)
        @conn.onclose = (event) => @onConnClose(event)


    resetBufferTimer: ->
      clearTimeout(@sendBufferTimer)
      @sendBufferTimer = setTimeout((=> @flushSendBuffer()), @flushEveryMs)


    # Logs the message. Override `@logger` for specialized logging. noops by default
    log: (msg) -> @logger(msg)

    # Registers callbacks for connection state change events
    #
    # Examples
    #
    #    socket.onError (error) -> alert("An error occurred")
    #
    onOpen:  (callback) -> @stateChangeCallbacks.open.push(callback) if callback
    onClose: (callback) -> @stateChangeCallbacks.close.push(callback) if callback
    onError: (callback) -> @stateChangeCallbacks.error.push(callback) if callback
    onMessage: (callback) -> @stateChangeCallbacks.message.push(callback) if callback

    onConnOpen: ->
      clearInterval(@reconnectTimer)
      unless @transport.skipHeartbeat
        @heartbeatTimer = setInterval (=> @sendHeartbeat() ), @heartbeatIntervalMs
      @rejoinAll()
      callback() for callback in @stateChangeCallbacks.open


    onConnClose: (event) ->
      @log("WS close:")
      @log(event)
      clearInterval(@reconnectTimer)
      clearInterval(@heartbeatTimer)
      @reconnectTimer = setInterval (=> @reconnect() ), @reconnectAfterMs
      callback(event) for callback in @stateChangeCallbacks.close


    onConnError: (error) ->
      @log("WS error:")
      @log(error)
      callback(error) for callback in @stateChangeCallbacks.error


    connectionState: ->
      switch @conn?.readyState
        when @states.connecting   then "connecting"
        when @states.open         then "open"
        when @states.closing      then "closing"
        when @states.closed, null then "closed"


    isConnected: -> @connectionState() is "open"

    rejoinAll: -> @rejoin(chan) for chan in @channels

    rejoin: (chan) ->
      chan.reset()
      {channel, topic, message} = chan
      @send(channel: channel, topic: topic, event: "join", message: message)
      chan.callback(chan)


    join: (channel, topic, message, callback) ->
      chan = new exports.Channel(channel, topic, message, callback, this)
      @channels.push(chan)
      @rejoin(chan) if @isConnected()


    leave: (channel, topic, message = {}) ->
      @send(channel: channel, topic: topic, event: "leave", message: message)
      @channels = (c for c in @channels when not(c.isMember(channel, topic)))


    send: (data) ->
      callback = => @conn.send(JSON.stringify(data))
      if @isConnected()
        callback()
      else
        @sendBuffer.push callback


    sendHeartbeat: ->
      @send(channel: "phoenix", topic: "conn", event: "heartbeat", message: {})


    flushSendBuffer: ->
      if @isConnected() and @sendBuffer.length > 0
        callback() for callback in @sendBuffer
        @sendBuffer = []
      @resetBufferTimer()


    onConnMessage: (rawMessage) ->
      @log("message received:")
      @log(rawMessage)
      {channel, topic, event, message} = JSON.parse(rawMessage.data)
      for chan in @channels when chan.isMember(channel, topic)
        chan.trigger(event, message)
      callback(channel, topic, event, message) for callback in @stateChangeCallbacks.message



  class exports.LongPoller

    retryInMs: 5000
    endPoint: null
    skipHeartbeat: true
    onopen:    -> # noop
    onerror:   -> # noop
    onmessage: -> # noop
    onclose:   -> # noop

    constructor: (endPoint) ->
      @states     = exports.Socket.states
      @endPoint   = @normalizeEndpoint(endPoint)
      @readyState = @states.connecting
      @open()


    open: ->
      exports.Ajax.request "POST", @endPoint, "application/json", null, (status, resp) =>
        if status is 200
          @readyState = @states.open
          @onopen()
          @poll()
        else
          @onerror()


    normalizeEndpoint: (endPoint) ->
      suffix = if /\/$/.test(endPoint) then "poll" else "/poll"
      endPoint.replace("ws://", "http://").replace("wss://", "https://") + suffix


    poll: ->
      return unless @readyState is @states.open
      exports.Ajax.request "GET", @endPoint, "application/json", null, (status, resp) =>
        switch status
          when 200
            @onmessage(data: JSON.stringify(msg)) for msg in JSON.parse(resp)
            @poll()
          when 204
            @poll()
          else
            @close()
            setTimeout (=> @open()), @retryInMs


    send: (body) ->
      exports.Ajax.request "PUT", @endPoint, "application/json", body, (status, resp) =>
        @onerror() unless status is 200


    close: (code, reason) ->
      @readyState = @states.closed
      @onclose()


  exports.Ajax =

    states: {complete: 4}

    request: (method, endPoint, accept, body, callback) ->
      req = if root.XMLHttpRequest?
        new root.XMLHttpRequest() # IE7+, Firefox, Chrome, Opera, Safari
      else
        new root.ActiveXObject("Microsoft.XMLHTTP") # IE6, IE5
      req.open method, endPoint, true
      req.setRequestHeader("Content-type", accept)
      req.onreadystatechange = =>
        callback?(req.status, req.responseText) if req.readyState is @states.complete

      req.send(body)



  exports
