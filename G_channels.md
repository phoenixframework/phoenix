Channels are a really exciting and powerful part of Phoenix that allow us to easily add soft-realtime features to our applications. Channels are based on a simple idea - sending and receiving messages. Senders broadcast messages about topics. Receivers subscribe to topics so that they can get those messages. Senders and receivers can switch roles on the same topic at any time.

Since Elixir is based on message passing, you may wonder why we need this extra mechanism to send and receive messages. With Channels, neither senders nor receivers have to be Elixir processes. They can be anything that we can teach to communicate over a Channel - a JavaScript client, an iOS app, another Phoenix application, our watch. Also, messages broadcast over a Channel may have many receivers. Elixir processes communicate one to one.

The word "Channel" is really shorthand for a layered system with a number of components. Let's take a quick look at them now so we can see the big picture a little better.

#### The Moving Parts

- Socket Handlers

Phoenix holds a single connection to the server and multiplexes your channel sockets over that one connection. Socket handlers, such as `web/channels/user_socket.ex`, are modules that authenticate and identify a socket connection and allow you to set default socket assigns for use in all channels.

- Channel Routes

These are defined in Socket handlers, such as `web/channels/user_socket.ex`, which makes them distinct from other routes. They match on the topic string and dispatch matching requests to the given Channel module. The star character `*` acts as a wildcard matcher, so in the following example route, requests for `sample_topic:pizza` and `sample_topic:oranges` would both be dispatched to the `SampleTopicChannel`.

```elixir
channel "sample_topic:*", HelloPhoenix.SampleTopicChannel
```

- Channels

Channels handle events from clients, so they are similar to Controllers, but there are two key differences. Channel events can go both directions - incoming and outgoing. Channel connections also persist beyond a single request/response cycle. Channels are the highest level abstraction for realtime communication components in Phoenix.

Each Channel will implement one or more clauses of each of these four callback functions - `join/3`, `terminate/2`, `handle_in/3`, and `handle_out/3`.

- PubSub

The Phoenix PubSub layer consists of the `Phoenix.PubSub` module and a variety of modules for different adapters and their `GenServer`s. These modules contain functions which are the nuts and bolts of organizing Channel communication - subscribing to topics, unsubscribing from topics, and broadcasting messages on a topic.

We can also define our own PubSub adapters if we need to. Please see the [Phoenix.PubSub docs](http://hexdocs.pm/phoenix/Phoenix.PubSub.html) for more information.

It is worth noting that these modules are intended for Phoenix's internal use. Channels use them under the hood to do much of their work. As end users, we shouldn't have any need to use them directly in our applications.

- Messages

The `Phoenix.Socket.Message` module defines a struct with the following keys which denotes a valid message. From the [Phoenix.Socket.Message docs](http://hexdocs.pm/phoenix/Phoenix.Socket.Message.html).
  - `topic` - The String topic or topic:subtopic pair namespace, i.e. “messages”, “messages:123”
  - `event` - The String event name, ie “join”
  - `payload` - The String JSON message payload
  - `ref` - The unique string used for replying to incoming events

- Topics

Topics are string identifiers - names that the various layers use in order to make sure messages end up in the right place. As we saw above, topics can use wildcards. This allows for a useful "topic:subtopic" convention. Often, you'll compose topics using record IDs from your model layer, such as `"users:123"`.

- Transports

The transport layer is where the rubber meets the road. The `Phoenix.Channel.Transport` module handles all the message dispatching into and out of a Channel.

- Transport Adapters

The default transport mechanism is via WebSockets which will fall back to LongPolling if WebSockets are not available. Other transport adapters are possible, and we can write our own if we follow the adapter contract. Please see `Phoenix.Transports.WebSocket` for an example.

- Client Libraries

Phoenix currently ships with its own JavaScript client. [iOS](https://github.com/davidstump/SwiftPhoenixClient), [Android](https://github.com/eoinsha/JavaPhoenixChannels), and [C#](https://github.com/livehelpnow/CSharpPhoenixClient) clients have been released with Phoenix 1.0.

## Tying it all together
Let's tie all these ideas together by building a simple chat application. After [generating a new Phoenix application](http://www.phoenixframework.org/docs/up-and-running) we'll see that the endpoint is already set up for us in `lib/hello_phoenix/endpoint.ex`:

```elixir
defmodule HelloPhoenix.Endpoint do
  use Phoenix.Endpoint, otp_app: :hello_phoenix

  socket "/socket", HelloPhoenix.UserSocket
  ...
end
```

In `web/channels/user_socket.ex`, the `HelloPhoenix.UserSocket` we pointed to in our endpoint has already been created when we generated our application. We need to make sure messages get routed to the correct channel. To do that, we'll uncomment the "rooms:*" channel definition:

```elixir
defmodule HelloPhoenix.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel "rooms:*", HelloPhoenix.RoomChannel
  ...
```

Now, whenever a client sends a message whose topic starts with `"rooms:"`, it will be routed to our RoomChannel. Next, we'll define a `HelloPhoenix.RoomChannel` module to manage our chat room messages.

### Joining Channels

The first priority of your channels is to authorize clients to join a given topic. For authorization, we must implement `join/3` in `web/channels/room_channel.ex`.

```elixir
defmodule HelloPhoenix.RoomChannel do
  use Phoenix.Channel

  def join("rooms:lobby", _message, socket) do
    {:ok, socket}
  end
  def join("rooms:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end
end
```

For our chat app, we'll allow anyone to join the `"rooms:lobby"` topic, but any other room will be considered private and special authorization, say from a database, will be required. We won't worry about private chat rooms for this exercise, but feel free to explore after we finish. To authorize the socket to join a topic, we return `{:ok, socket}` or `{:ok, reply, socket}`. To deny access, we return `{:error, reply}`. More information about authorization with tokens can be found in the [`Phoenix.Token` documentation](http://hexdocs.pm/phoenix/Phoenix.Token.html).

With our channel in place, let's get the client and server talking. There's some code in `web/static/js/socket.js` to connect to our socket and join our channel already, we just need to set our room name to "rooms:lobby".

```javascript
...
socket.connect()

// Now that you are connected, you can join channels with a topic:
let channel = socket.channel("rooms:lobby", {})
channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket
```

After that, we need to make sure `web/static/socket.js` gets imported into our application javascript file. To do that, uncomment the last line in `web/static/js/app.js`.

```javascript
...
import socket from "./socket"
```

Save the file and your browser should auto refresh, thanks to the Phoenix live reloader. If everything worked, we should see "Joined successfully" in the browser's JavaScript console. Our client and server are now talking over a persistent connection. Now let's make it useful by enabling chat.

In `web/templates/page/index.html.eex`, we'll replace the existing code with a container to hold our chat messages, and an input field to send them:

```html
<div id="messages"></div>
<input id="chat-input" type="text"></input>
```

We'll also add jQuery to our application layout in `web/templates/layout/app.html.eex`:

```html
  ...
    <%= @inner %>

  </div> <!-- /container -->
  <script src="//code.jquery.com/jquery-1.11.3.min.js"></script>
  <script src="<%= static_path(@conn, "/js/app.js") %>"></script>
</body>
```

Now let's add a couple of event listeners to `web/static/js/socket.js`:

```javascript
...
let channel           = socket.channel("rooms:lobby", {})
let chatInput         = $("#chat-input")
let messagesContainer = $("#messages")

chatInput.on("keypress", event => {
  if(event.keyCode === 13){
    channel.push("new_msg", {body: chatInput.val()})
    chatInput.val("")
  }
})

channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket
```

All we had to do is detect that enter was pressed and then `push` an event over the channel with the message body. We named the event "new_msg". With this in place, let's handle the other piece of a chat application where we listen for new messages and append them to our messages container.

```javascript
...
let channel           = socket.channel("rooms:lobby", {})
let chatInput         = $("#chat-input")
let messagesContainer = $("#messages")

chatInput.on("keypress", event => {
  if(event.keyCode === 13){
    channel.push("new_msg", {body: chatInput.val()})
    chatInput.val("")
  }
})

channel.on("new_msg", payload => {
  messagesContainer.append(`<br/>[${Date()}] ${payload.body}`)
})

channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket
```

We listen for the `"new_msg"` event using `channel.on`, and then append the message body to the DOM. Now let's handle the incoming and outgoing events on the server to complete the picture.

### Incoming Events
We handle incoming events with `handle_in/3`. We can pattern match on the event names, like `"new_msg"`, and then grab the payload that the client passed over the channel. For our chat application, we simply need to notify all other `rooms:lobby` subscribers of the new message with `broadcast!/3`.

```elixir
defmodule HelloPhoenix.RoomChannel do
  use Phoenix.Channel

  def join("rooms:lobby", _message, socket) do
    {:ok, socket}
  end
  def join("rooms:" <> _private_room_id, _params, _socket) do
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

`broadcast!/3` will notify all joined clients on this `socket`'s topic and invoke their `handle_out/3` callbacks. `handle_out/3` isn't a required callback, but it allows us to customize and filter broadcasts before they reach each client. By default, `handle_out/3` is implemented for us and simply pushes the message on to the client, just like our definition. We included it here because hooking into outgoing events allows for powerful message customization and filtering. Let's see how.

#### Intercepting Outgoing Events
We won't implement this for our application, but imagine our chat app allowed users to ignore messages about new users joining a room. We could implement that behavior like this where we explicitly tell Phoenix which outgoing event we want to intercept and then define a `handle_out/3` callback for those events. (Of course, this assumes that we have a `User` model with an `ignoring?/2` function, and that we pass a user in via the `assigns` map.)

```elixir
intercept ["user_joined"]

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

#### Socket Assigns

Similar to connection structs, `%Plug.Conn{}`, it is possible to assign values to a channel socket. `Phoenix.Socket.assign/3` is conveniently imported into a channel module as `assign/3`:

```elixir
socket = assign(socket, :user, msg["user"])
```

Sockets store assigned values as a map in `socket.assigns`.

#### Example Application
To see an example of the application we just built, checkout this project (https://github.com/chrismccord/phoenix_chat_example).

You can also see a live demo at (http://phoenixchat.herokuapp.com/).
