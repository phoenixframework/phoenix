((root, factory) ->
  if typeof define == "function" && define.amd
    define(["phoenix"], factory)
  else if typeof exports == "object"
    factory(exports)
  else
    factory((root.Phoenix = {}))
) @, (exports) ->

  class exports.Channel

    bindings: null

    constructor: (@channel, @topic, @message, @callback, @onJoin, @socket) ->
      @reset()


    reset: ->
      if @onJoin
        @bindings = [{event: "join", callback: @onJoin}]
      else
        @bindings = []

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

    constructor: (endPoint, opts = {}) ->
      @heartbeatIntervalMs = opts.heartbeatIntervalMs ? @heartbeatIntervalMs
      @endPoint = @expandEndpoint(endPoint)
      @channels = []
      @sendBuffer = []
      @stateChangeCallbacks = {open: [], close: [], error: []}
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
        @conn = new WebSocket(@endPoint)
        @conn.onopen = => @onConnOpen()
        @conn.onerror = (error) => @onConnError(error)
        @conn.onmessage = (event) =>  @onMessage(event)
        @conn.onclose = (event) => @onConnClose(event)


    resetBufferTimer: ->
      clearTimeout(@sendBufferTimer)
      @sendBufferTimer = setTimeout((=> @flushSendBuffer()), @flushEveryMs)


    # Registers callbacks for connection state change events
    #
    # Examples
    #
    #    socket.onError (error) -> alert("An error occurred")
    #
    onOpen:  (callback) -> @stateChangeCallbacks.open.push(callback) if callback
    onClose: (callback) -> @stateChangeCallbacks.close.push(callback) if callback
    onError: (callback) -> @stateChangeCallbacks.error.push(callback) if callback

    onConnOpen: ->
      clearInterval(@reconnectTimer)
      @heartbeatTimer = setInterval (=> @sendHeartbeat() ), @heartbeatIntervalMs
      @rejoinAll()
      callback() for callback in @stateChangeCallbacks.open


    onConnClose: (event) ->
      console.log?("WS close: ", event)
      clearInterval(@reconnectTimer)
      clearInterval(@heartbeatTimer)
      @reconnectTimer = setInterval (=> @reconnect() ), @reconnectAfterMs
      callback(event) for callback in @stateChangeCallbacks.close


    onConnError: (error) ->
      console.log?("WS error: ", error)
      callback(error) for callback in @stateChangeCallbacks.error


    connectionState: ->
      switch @conn?.readyState
        when WebSocket.CONNECTING   then "connecting"
        when WebSocket.OPEN         then "open"
        when WebSocket.CLOSING      then "closing"
        when WebSocket.CLOSED, null then "closed"


    isConnected: -> @connectionState() is "open"

    rejoinAll: -> @rejoin(chan) for chan in @channels

    rejoin: (chan) ->
      chan.reset()
      {channel, topic, message} = chan
      @send(channel: channel, topic: topic, event: "join", message: message)
      chan.callback(chan)


    join: (channel, topic, message, callback, onJoin) ->
      chan = new exports.Channel(channel, topic, message, callback, onJoin, this)
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


    onMessage: (rawMessage) ->
      console.log?("message received: ", rawMessage)
      {channel, topic, event, message} = JSON.parse(rawMessage.data)
      for chan in @channels when chan.isMember(channel, topic)
        chan.trigger(event, message)

  exports