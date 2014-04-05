@Phoenix = {}


class @Phoenix.Channel

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



class @Phoenix.Socket

  conn: null
  endPoint: null
  channels: null
  sendBuffer: null
  sendBufferTimer: null
  flushEveryMs: 50
  reconnectTimer: null
  reconnectAfterMs: 5000


  constructor: (@endPoint) ->
    @channels = []
    @sendBuffer = []
    @resetBufferTimer()
    @reconnect()


  close: (callback) ->
    if @conn?
      @conn.onclose = =>
      @conn.close()
      @conn = null
    callback?()


  reconnect: ->
    @close =>
      @conn = new WebSocket(@endPoint)
      @conn.onopen = => @onOpen()
      @conn.onerror = (error) => @onError(error)
      @conn.onmessage = (event) =>  @onMessage(event)
      @conn.onclose = (event) => @onClose(event)


  resetBufferTimer: ->
    clearTimeout(@sendBufferTimer)
    @sendBufferTimer = setTimeout((=> @flushSendBuffer()), @flushEveryMs)


  onOpen: ->
    clearInterval(@reconnectTimer)
    @rejoinAll()


  onClose: (event) ->
    console.log?("WS close: #{event}")
    clearInterval(@reconnectTimer)
    @reconnectTimer = setInterval (=> @reconnect() ), @reconnectAfterMs


  onError: (error) -> console.log?("WS error: #{error}")

  connectionState: ->
    switch @conn?.readyState ? 3
      when 0 then "connecting"
      when 1 then "open"
      when 2 then "closing"
      when 3 then "closed"


  isConnected: -> @connectionState() is "open"

  rejoinAll: -> @rejoin(chan) for chan in @channels

  rejoin: (chan) ->
    chan.reset()
    {channel, topic, message} = chan
    @send(channel: channel, topic: topic, event: "join", message: message)
    chan.callback(chan)


  join: (channel, topic, message, callback) ->
    chan = new Phoenix.Channel(channel, topic, message, callback, this)
    @channels.push(chan)
    @rejoin(chan) if @isConnected()


  leave: (channel, topic, message = {}) ->
    @send({channel, topic, "leave", message})
    @channels = (c for c in @channels when not(c.isMember(channel, topic)))


  send: (data) ->
    callback = => @conn.send(JSON.stringify(data))
    if @isConnected()
      callback()
    else
      @sendBuffer.push callback


  flushSendBuffer: ->
    if @isConnected() and @sendBuffer.length > 0
      callback() for callback in @sendBuffer
      @sendBuffer = []
    @resetBufferTimer()


  onMessage: (rawMessage) ->
    console.log? rawMessage
    {channel, topic, event, message} = JSON.parse(rawMessage.data)
    for chan in @channels when chan.isMember(channel, topic)
      chan.trigger(event, message)


