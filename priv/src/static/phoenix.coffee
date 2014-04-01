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




class @Phoenix.Socket

  conn: null
  endPoint: null
  channels: null

  constructor: (@endPoint) ->
    @channels = []
    @reconnect()


  reconnect: ->
    @conn = new WebSocket(@endPoint)
    @conn.onopen = => @onOpen()
    @conn.onerror = (error) => @onError(error)
    @conn.onmessage = (event) =>  @onMessage(event)
    @conn.onclose = (event) => @onClose(event)


  onClose: (event) ->
    console.log("WS: #{event}")
    # @reconnect()


  onOpen: -> @rejoinAll()

  onError: (error) -> console.log?("WS: #{error}")

  rejoinAll: -> @rejoin(chan) for chan in @channels

  rejoin: (chan) ->
    chan.reset()
    {channel, topic, message} = chan
    @send(channel: channel, topic: topic, event: "join", message: message)

    chan.callback(chan)


  join: (channel, topic, message, callback) ->
    chan = new Phoenix.Channel(channel, topic, message, callback, this)
    @channels.push(chan)
    @rejoin(chan)


  unjoin: (channel, topic) ->
    @channels = (c for c in @channels when not(c.isMember(channel, topic)))


  send: (data) ->
    console.log "Sending: #{data}"
    @conn.send(JSON.stringify(data))

  onMessage: (rawMessage) ->
    console.log rawMessage
    {channel, topic, event, message} = JSON.parse(rawMessage.data)
    for chan in @channels when chan.isMember(channel, topic)
      chan.trigger(event, message)


# socket = new Phoenix.Socket("")
# socket.join "messages", room, (channel) ->
#   channel.on "user:entered" ->
#   channel.on "user:leave", ->
#
# socket.join "messages", "global", (channel) ->
#   channel.on "user:entered", ->
#
# socket.join "messages", organization, (channel) ->
#   channel.on "join", ->
#   channel.on "error", ->
#   channel.on "new", ->





