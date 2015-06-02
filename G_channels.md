Channels are a really exciting and powerful part of Phoenix, one that allows us to easily add soft-realtime features to our applications. Channels are based on a simple idea - sending and receiving messages. Senders broadcast messages about topics. Receivers subscribe to topics so that they can get those messages. Senders and receivers can switch roles on the same topic at any time.

Since Elixir is based on message passing, you may wonder why we need this extra mechanism to send and receive messages. With Channels, neither senders nor receivers have to be Elixir processes. They can be anything that we can teach to communicate over a Channel - a JavaScript client, an iOS app, another Phoenix application, our watch. Also, messages broadcast over a Channel may have many receivers. Elixir processes communicate one to one.

The word "Channel" is really shorthand for a layered system with a number of components. Let's take a quick look at them now so we can see the big picture a little better.

#### The Moving Parts
- Channel Routes

These are defined in the `router.ex` file as all other routes are. They match on the topic string and dispatch matching requests to the given Channel module. The star character `*` acts as a wildcard matcher, so in the following example route, requests for `sample_topic:pizza` and `sample_topic:oranges` would both be dispatched to the `SampleTopicChannel`.

```elixir
socket "/ws", HelloPhoenix do
  channel "sample_topic:*", SampleTopicChannel
end
```
For more details on channel routes, please see the [Routing Guide](http://www.phoenixframework.org/docs/routing).

- Channels

Channels handle requests, so they are similar to Controllers, but there are two key differences. Channel requests can go both directions - incoming and outgoing. Channel connections also persist beyond a single request/response cycle. Channels are the highest level abstraction for realtime communication components in Phoenix.

Each Channel will implement one or more clauses of each of these four callback functions - `join/3`, `terminate/2`, `handle_in/3`, and `handle_out/3`.

- PubSub

The Phoenix PubSub layer consists of the `Phoenix.PubSub` module and a variety of modules for different adapters and their Genservers. These modules contain functions which are the nuts and bolts of organizing Channel communication - subscribing to topics, unsubscribing from topics, and broadcasting messages on a topic.

We can also define our own PubSub adapters if we need to. Please see the [Phoenix.PubSub docs](http://hexdocs.pm/phoenix/) for more information.

It is worth noting that these modules are intended for Phoenix's internal use. Channels use them under the hood to do much of their work. As end users, we shouldn't have any need to use them directly in our applications.

- Messages

The `Phoenix.Socket.Message` module defines a struct with the following keys which denotes a valid message. From the [Phoenix.Socket.Message docs](http://hexdocs.pm/phoenix/Phoenix.Socket.Message.html).
  - `topic` - The String topic or topic:subtopic pair namespace, ie “messages”, “messages:123”
  - `event` - The String event name, ie “join”
  - `payload` - The String JSON message payload
  - `ref` - The unique string used for replying to incoming events

- Topics

Topics are string identifiers - names that the various layers use in order to make sure messages end up in the right place. As we saw above, topics can use wildcards. This allows for a useful "topic:subtopic" convention. Often, you'll compose topics using record IDs from your model layer, such as `"users:123"`.

- Transports

The transport layer is where the rubber meets the road. The `Phoenix.Channel.Transport` module handles all the message dispatching into and out of a Channel.

- Transport Adapters

The default transport mechanism is via WebSockets which will fall back to LongPolling if WebSockets are not available/working. Other transport adapters are possible, and indeed, we can write our own if we follow the adapter contract. Please see `Phoenix.Transports.WebSocket` for an example.

- Client Libraries

Phoenix currently ships with its own JavaScript client and iOS and Android clients are planned for release with Phoenix 1.0.

## Tying it all together
Let's tie all these ideas together by building a simple chat application. Let's start by wiring up our channel routes.

```elixir
defmodule HelloPhoenix.Router do
   use HelloPhoenix.Web, :router

   socket "/ws", HelloPhoenix do
     channel "rooms:*", RoomChannel
   end
   ...
end
```

Now any topic sent by a client that starts with `"rooms:"` will be routed to our RoomChannel. Next, we'll define a `RoomChannel` module to manage our chat room messages.


### Joining Channels

The first priority of your channels is to authorize clients to join a given topic. For authorization, we must implement `join/3` in `web/channels/room_channel.ex`.

```elixir
defmodule HelloPhoenix.RoomChannel do
  use Phoenix.Channel

  def join("rooms:lobby", auth_msg, socket) do
    {:ok, socket}
  end
  def join("rooms:" <> _private_room_id, _auth_msg, socket) do
    {:error, %{reason: "unauthorized"}}
  end

end
```

For our chat app, we'll allow anyone to join the `"rooms:lobby"` topic, but any other room will be considered private and special authorization, say from a database, will be required. We won't worry about private chat rooms for this exercise, but feel free to explore after we finish. To authorize the socket to join a topic, we return `{:ok, socket}` or `{:ok, reply, socket}`. To deny access, we return `{:error, reply}`.


With our channel in place, lets head over to `web/static/js/app.js` and get the client and server talking.

```javascript
let socket = new Socket("/ws")
socket.connect()
let chan = socket.chan("rooms:lobby", {})
chan.join().receive("ok", chan => {
  console.log("Welcome to Phoenix Chat!")
})
```

Save the file and your browser should auto refresh, thanks to the Phoenix live reloader. If everything worked, we should see "Welcome to Phoenix Chat!" in the browser's JavaScript console. Our client and server are now talking over a persistent connection. Now let's make it useful by enabling chat.

In your `web/templates/page/index.html.eex`, add a container to hold our chat messages, and an input field to send them.

```html
<div id="messages"></div>
<input id="chat-input" type="text"></input>
```

We'll also add jQuery to our application layout in `web/templates/layout/application.html.eex`:

```html
  ...
    <%= @inner %>

  </div> <!-- /container -->
  <script src="//code.jquery.com/jquery-1.11.2.min.js"></script>
  <script src="<%= static_path(@conn, "/js/app.js") %>"></script>
  <script>require("web/static/js/app")</script>
</body>
```

Now let's add a couple event listeners to `app.js`:

```javascript
let chatInput         = $("#chat-input")
let messagesContainer = $("#messages")

let socket = new Socket("/ws")
socket.connect()
let chan = socket.chan("rooms:lobby", {})

chatInput.on("keypress", event => {
  if(event.keyCode === 13){
    chan.push("new_msg", {body: chatInput.val()})
    chatInput.val("")
  }
})

chan.join().receive("ok", chan => {
  console.log("Welcome to Phoenix Chat!")
})
```

All we had to do is detect that enter was pressed and then `push` an event over the channel with the message body. We named the event "new_msg". With this in place, let's handle the other piece of a chat application where we listen for new messages and append them to our messages container.


```javascript
let chatInput         = $("#chat-input")
let messagesContainer = $("#messages")

let socket = new Socket("/ws")
socket.connect()
let chan = socket.chan("rooms:lobby", {})

chatInput.on("keypress", event => {
  if(event.keyCode === 13){
    chan.push("new_msg", {body: chatInput.val()})
    chatInput.val("")
  }
})

chan.on("new_msg", payload => {
  messagesContainer.append(`<br/>[${Date()}] ${payload.body}`)
})

chan.join().receive("ok", chan => {
  console.log("Welcome to Phoenix Chat!")
})
```

We listen for the `"new_msg"` event using `chan.on`, and then append the message body to the DOM. Now let's handle the incoming and outgoing events on the server to complete the picture.

### Incoming Events
We handle incoming events with `handle_in/3`. We can pattern match on the event names, like `"new_msg"`, and then grab the payload that the client passed over the channel. For our chat application, we simply need to notify all other `rooms:lobby` subscribers of the new message with `broadcast!/3`.

```elixir
defmodule HelloPhoenix.RoomChannel do
  use Phoenix.Channel

  def join("rooms:lobby", auth_msg, socket) do
    {:ok, socket}
  end
  def join("rooms:" <> _private_room_id, _auth_msg, socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_in("new_msg", %{"body" => body}, socket) do
    broadcast! socket, "new_msg", %{body: body}
    {:noreply, socket}
  end

  def handle_out("new_msg", payload, socket) do
    push socket, "new_msg", payload
    {:noreply, socket}
  end
end
```

`broadcast!/3` will notify all joined clients on this `socket`'s topic and invoke their `handle_out/3` callbacks. `handle_out/3` isn't required callback, but it allows us to customize and filter broadcasts before they reach each client. By default, `handle_out/3` is implemented for us and simply pushes the message on to the client, just like our definition. We included it here because hooking into outgoing events allows for powerful messages customization and filtering. Let's see how.

#### Outgoing Events
We won't implement this for our application, but imagine our chat app allowed users to ignore messages about new users joining a room. We could implement that behavior like this. (Of course, this assumes that we have a `User` model with an `ignoring?/2` function, and that we pass a user in via the `assigns` map.)

```elixir
def handle_out("user_joined", msg, socket) do
  if User.ignoring?(socket.assigns[:user], msg.user_id) do
    {:noreply, socket}
  else
    push socket, "user_joined", msg
    {:noreply, socket}
  end
end
```

That's all there is to our basic chat app. Fire up multiple browser tabs and you should see your messages being pushed and broadcasted to all windows!


#### Example Application
To see an example of the application we just built, checkout this project (https://github.com/chrismccord/phoenix_chat_example).

You can also see a live demo at (http://phoenixchat.herokuapp.com/).
