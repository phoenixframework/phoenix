@Phoenix = {}


class @Phoenix.Socket

  conn: null
  endPoint: null
  subscriptions: null
  awaitingJoins: null

  constructor: (@endPoint) ->
    @subscriptions = []
    @awaitingJoins = []
    @connect()


  connect: ->
    @conn = new WebSocket(@endPoint)
    @conn.onopen = =>
      @subscribeAll()
      @joinAll()
      @onOpen()

    @conn.onerror = (error) => @onError(error)
    @conn.onmessage = (event) =>  @onEvent(event)


  onOpen: -> #noop

  # Retrigger all subscriptions
  subscribeAll: ->
    @subscribe(sub) for sub in @subscriptions

  # Retrigger all joins
  joinAll: ->
    @join(join) for join in @awaitingJoins


  join: (channel, topic, callback) ->
    @awaitingJoins.push({topic: topic, callback: callback})
    @send({channel: channel, event: "join", message: {topic: topic}})


  send: ({channel, event, message}) ->
    @conn.send(JSON.stringify({channel, event, message}))


  onError: (error) -> console.log?("WS: #{error}")

  subscribe: (channel, topic, callback) ->
    @subscriptions.push({channel, topic, callback})


  unsubscribe: (channel, topic) ->
    for sub, index in @subscriptions when sub.channel is channel and sub.topic is topic
      @subscriptions.splice(index, 1)


  onEvent: (event) ->
    eventData = JSON.parse(event.data)
    console.log eventData
    {channel, topic, event, message} = eventData

    switch event
      when "join:success" then @triggerAwaitingJoinSuccess(topic, message)
      when "join:failure" then @triggerAwaitingJoinFailure(topic, message)
      else
        @triggerSubscriptionCallback(channel, topic, message)


  triggerSubscriptionCallback: (channel, topic, message) ->
    for sub, index in @subscriptions when sub.channel is channel and sub.topic is topic
      sub.callback?(message)


  triggerAwaitingJoinSuccess: (joinedTopic, message) ->
    for {topic, callback}, index in @awaitingJoins when topic is joinedTopic
      callback?(null, message)
      @awaitingJoins.splice(index, 1)


  triggerAwaitingJoinFailure: (joinedTopic, message) ->
    for {topic, callback} in @awaitingJoins when topic is joinedTopic
      callback?(err, message)
      @awaitingJoins.splice(index, 1)



