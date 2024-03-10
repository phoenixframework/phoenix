# Channels

> **Requirement**: This guide expects that you have gone through the [introductory guides](installation.html) and got a Phoenix application [up and running](up_and_running.html).

Channels are an exciting part of Phoenix that enable soft real-time communication with and between millions of connected clients.

Some possible use cases include:

- Chat rooms and APIs for messaging apps
- Breaking news, like "a goal was scored" or "an earthquake is coming"
- Tracking trains, trucks, or race participants on a map
- Events in multiplayer games
- Monitoring sensors and controlling lights
- Notifying a browser that a page's CSS or JavaScript has changed (this is handy in development)

Conceptually, Channels are pretty simple.

First, clients connect to the server using some transport, like WebSocket. Once connected, they join one or more topics. For example, to interact with a public chat room clients may join a topic called `public_chat`, and to receive updates from a product with ID 7, they may need to join a topic called `product_updates:7`.

Clients can push messages to the topics they've joined, and can also receive messages from them. The other way around, Channel servers receive messages from their connected clients, and can push messages to them too.

Servers are able to broadcast messages to all clients subscribed to a certain topic. This is illustrated in the following diagram:

```plaintext
                                                                  +----------------+
                                                     +--Topic X-->| Mobile Client  |
                                                     |            +----------------+
                              +-------------------+  |
+----------------+            |                   |  |            +----------------+
| Browser Client |--Topic X-->| Phoenix Server(s) |--+--Topic X-->| Desktop Client |
+----------------+            |                   |  |            +----------------+
                              +-------------------+  |
                                                     |            +----------------+
                                                     +--Topic X-->|   IoT Client   |
                                                                  +----------------+
```

Broadcasts work even if the application runs on several nodes/computers. That is, if two clients have their socket connected to different application nodes and are subscribed to the same topic `T`, both of them will receive messages broadcasted to `T`. That is possible thanks to an internal PubSub mechanism.

Channels can support any kind of client: a browser, native app, smart watch, embedded device, or anything else that can connect to a network.
All the client needs is a suitable library; see the [Client Libraries](#client-libraries) section below.
Each client library communicates using one of the "transports" that Channels understand.
Currently, that's either Websockets or long polling, but other transports may be added in the future.

Unlike stateless HTTP connections, Channels support long-lived connections, each backed by a lightweight BEAM process, working in parallel and maintaining its own state.

This architecture scales well; Phoenix Channels [can support millions of subscribers with reasonable latency on a single box](https://phoenixframework.org/blog/the-road-to-2-million-websocket-connections), passing hundreds of thousands of messages per second.
And that capacity can be multiplied by adding more nodes to the cluster.

## The Moving Parts

Although Channels are simple to use from a client perspective, there are a number of components involved in routing messages to clients across a cluster of servers.
Let's take a look at them.

### Overview

To start communicating, a client connects to a node (a Phoenix server) using a transport (e.g., Websockets or long polling) and joins one or more channels using that single network connection.
One channel server lightweight process is created per client, per topic. Each channel holds onto the `%Phoenix.Socket{}` and can maintain any state it needs within its `socket.assigns`.

Once the connection is established, each incoming message from a client is routed, based on its topic, to the correct channel server.
If the channel server asks to broadcast a message, that message is sent to the local PubSub, which sends it out to any clients connected to the same server and subscribed to that topic.

If there are other nodes in the cluster, the local PubSub also forwards the message to their PubSubs, which send it out to their own subscribers.
Because only one message has to be sent per additional node, the performance cost of adding nodes is negligible, while each new node supports many more subscribers.

The message flow looks something like this:

```plaintext
                                 Channel   +-------------------------+      +--------+
                                  route    | Sending Client, Topic 1 |      | Local  |
                              +----------->|     Channel.Server      |----->| PubSub |--+
+----------------+            |            +-------------------------+      +--------+  |
| Sending Client |-Transport--+                                                  |      |
+----------------+                         +-------------------------+           |      |
                                           | Sending Client, Topic 2 |           |      |
                                           |     Channel.Server      |           |      |
                                           +-------------------------+           |      |
                                                                                 |      |
                                           +-------------------------+           |      |
+----------------+                         | Browser Client, Topic 1 |           |      |
| Browser Client |<-------Transport--------|     Channel.Server      |<----------+      |
+----------------+                         +-------------------------+                  |
                                                                                        |
                                                                                        |
                                                                                        |
                                           +-------------------------+                  |
+----------------+                         |  Phone Client, Topic 1  |                  |
|  Phone Client  |<-------Transport--------|     Channel.Server      |<-+               |
+----------------+                         +-------------------------+  |   +--------+  |
                                                                        |   | Remote |  |
                                           +-------------------------+  +---| PubSub |<-+
+----------------+                         |  Watch Client, Topic 1  |  |   +--------+  |
|  Watch Client  |<-------Transport--------|     Channel.Server      |<-+               |
+----------------+                         +-------------------------+                  |
                                                                                        |
                                                                                        |
                                           +-------------------------+      +--------+  |
+----------------+                         |   IoT Client, Topic 1   |      | Remote |  |
|   IoT Client   |<-------Transport--------|     Channel.Server      |<-----| PubSub |<-+
+----------------+                         +-------------------------+      +--------+
```

### Endpoint

In your Phoenix app's `Endpoint` module, a `socket` declaration specifies which socket handler will receive connections on a given URL.

```elixir
socket "/socket", HelloWeb.UserSocket,
  websocket: true,
  longpoll: false
```

Phoenix comes with two default transports: websocket and longpoll. You can configure them directly via the `socket` declaration.

### Socket Handlers

On the client side, you will establish a socket connection to the route above:

```javascript
let socket = new Socket("/socket", {params: {token: window.userToken}})
```

On the server, Phoenix will invoke `HelloWeb.UserSocket.connect/2`, passing your parameters and the initial socket state. Within the socket, you can authenticate and identify a socket connection and set default socket assigns. The socket is also where you define your channel routes.

### Channel Routes

Channel routes match on the topic string and dispatch matching requests to the given Channel module.

The star character `*` acts as a wildcard matcher, so in the following example route, requests for `room:lobby` and `room:123` would both be dispatched to the `RoomChannel`. In your `UserSocket`, you would have:

```elixir
channel "room:*", HelloWeb.RoomChannel
```

### Channels

Channels handle events from clients, so they are similar to Controllers, but there are two key differences. Channel events can go both directions - incoming and outgoing. Channel connections also persist beyond a single request/response cycle. Channels are the highest level abstraction for real-time communication components in Phoenix.

Each Channel will implement one or more clauses of each of these four callback functions - `join/3`, `terminate/2`, `handle_in/3`, and `handle_out/3`.

### Topics

Topics are string identifiers - names that the various layers use in order to make sure messages end up in the right place. As we saw above, topics can use wildcards. This allows for a useful `"topic:subtopic"` convention. Often, you'll compose topics using record IDs from your application layer, such as `"users:123"`.

### Messages

The `Phoenix.Socket.Message` module defines a struct with the following keys which denotes a valid message. From the [Phoenix.Socket.Message docs](https://hexdocs.pm/phoenix/Phoenix.Socket.Message.html).

- `topic` - The string topic or `"topic:subtopic"` pair namespace, such as `"messages"` or `"messages:123"`
- `event` - The string event name, for example `"phx_join"`
- `payload` - The message payload
- `ref` - The unique string ref

### PubSub

PubSub is provided by the `Phoenix.PubSub` module. Interested parties can receive events by subscribing to topics. Other processes can broadcast events to certain topics.

This is useful to broadcast messages on channel and also for application development in general. For instance, letting all connected [live views](https://github.com/phoenixframework/phoenix_live_view) to know that a new comment has been added to a post.

The PubSub system takes care of getting messages from one node to another so that they can be sent to all subscribers across the cluster.
By default, this is done using [Phoenix.PubSub.PG2](https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.PG2.html), which uses native BEAM messaging.

If your deployment environment does not support distributed Elixir or direct communication between servers, Phoenix also ships with a [Redis Adapter](https://hexdocs.pm/phoenix_pubsub_redis/Phoenix.PubSub.Redis.html) that uses Redis to exchange PubSub data. Please see the [Phoenix.PubSub docs](https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html) for more information.

### Client Libraries

Any networked device can connect to Phoenix Channels as long as it has a client library.
The following libraries exist today, and new ones are always welcome; to write your own, see our how-to guide [Writing a Channels Client](writing_a_channels_client.md).

#### Official

Phoenix ships with a JavaScript client that is available when generating a new Phoenix project. The documentation for the JavaScript module is available at [https://hexdocs.pm/phoenix/js/](https://hexdocs.pm/phoenix/js/); the code is in [multiple js files](https://github.com/phoenixframework/phoenix/blob/main/assets/js/phoenix/).

#### 3rd Party

+ Swift (iOS)
  - [SwiftPhoenix](https://github.com/davidstump/SwiftPhoenixClient)
+ Java (Android)
  - [JavaPhoenixChannels](https://github.com/eoinsha/JavaPhoenixChannels)
+ Kotlin (Android)
  - [JavaPhoenixClient](https://github.com/dsrees/JavaPhoenixClient)
+ C#
  - [PhoenixSharp](https://github.com/Mazyod/PhoenixSharp)
+ Elixir
  - [phoenix_gen_socket_client](https://github.com/Aircloak/phoenix_gen_socket_client)
  - [slipstream](https://hexdocs.pm/slipstream/Slipstream.html)
+ GDScript (Godot Game Engine)
  - [GodotPhoenixChannels](https://github.com/alfredbaudisch/GodotPhoenixChannels)

## Tying it all together

Let's tie all these ideas together by building a simple chat application. Make sure [you created a new Phoenix application](https://hexdocs.pm/phoenix/up_and_running.html) and now we are ready to generate the `UserSocket`.

### Generating a socket

Let's invoke the socket generator to get started:

```console
$ mix phx.gen.socket User
```

It will create two files, the client code in `assets/js/user_socket.js` and the server counter-part in `lib/hello_web/channels/user_socket.ex`. After running, the generator will also ask to add the following line to `lib/hello_web/endpoint.ex`:

```elixir
defmodule HelloWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :hello

  socket "/socket", HelloWeb.UserSocket,
    websocket: true,
    longpoll: false

  ...
end
```

The generator also asks us to import the client code, we will do that later.

Next, we will configure our socket to ensure messages get routed to the correct channel. To do that, we'll uncomment the `"room:*"` channel definition:

```elixir
defmodule HelloWeb.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel "room:*", HelloWeb.RoomChannel
  ...
```

Now, whenever a client sends a message whose topic starts with `"room:"`, it will be routed to our RoomChannel. Next, we'll define a `HelloWeb.RoomChannel` module to manage our chat room messages.

### Joining Channels

The first priority of your channels is to authorize clients to join a given topic. For authorization, we must implement `join/3` in `lib/hello_web/channels/room_channel.ex`.

```elixir
defmodule HelloWeb.RoomChannel do
  use Phoenix.Channel

  def join("room:lobby", _message, socket) do
    {:ok, socket}
  end

  def join("room:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end
end
```

For our chat app, we'll allow anyone to join the `"room:lobby"` topic, but any other room will be considered private and special authorization, say from a database, will be required.
(We won't worry about private chat rooms for this exercise, but feel free to explore after we finish.)

With our channel in place, let's get the client and server talking.

The generated `assets/js/user_socket.js` defines a simple client based on the socket implementation that ships with Phoenix.

We can use that library to connect to our socket and join our channel, we just need to set our room name to `"room:lobby"` in that file.

```javascript
// assets/js/user_socket.js
// ...
socket.connect()

// Now that you are connected, you can join channels with a topic:
let channel = socket.channel("room:lobby", {})
channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket
```

After that, we need to make sure `assets/js/user_socket.js` gets imported into our application JavaScript file. To do that, uncomment this line in `assets/js/app.js`.

```javascript
// ...
import "./user_socket.js"
```

Save the file and your browser should auto refresh, thanks to the Phoenix live reloader. If everything worked, we should see "Joined successfully" in the browser's JavaScript console. Our client and server are now talking over a persistent connection. Now let's make it useful by enabling chat.

In `lib/hello_web/controllers/page_html/home.html.heex`, we'll replace the existing code with a container to hold our chat messages, and an input field to send them:

```heex
<div id="messages" role="log" aria-live="polite"></div>
<input id="chat-input" type="text">
```

Now let's add a couple of event listeners to `assets/js/user_socket.js`:

```javascript
// ...
let channel           = socket.channel("room:lobby", {})
let chatInput         = document.querySelector("#chat-input")
let messagesContainer = document.querySelector("#messages")

chatInput.addEventListener("keypress", event => {
  if(event.key === 'Enter'){
    channel.push("new_msg", {body: chatInput.value})
    chatInput.value = ""
  }
})

channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket
```

All we had to do is detect that enter was pressed and then `push` an event over the channel with the message body. We named the event `"new_msg"`. With this in place, let's handle the other piece of a chat application, where we listen for new messages and append them to our messages container.

```javascript
// ...
let channel           = socket.channel("room:lobby", {})
let chatInput         = document.querySelector("#chat-input")
let messagesContainer = document.querySelector("#messages")

chatInput.addEventListener("keypress", event => {
  if(event.key === 'Enter'){
    channel.push("new_msg", {body: chatInput.value})
    chatInput.value = ""
  }
})

channel.on("new_msg", payload => {
  let messageItem = document.createElement("p")
  messageItem.innerText = `[${Date()}] ${payload.body}`
  messagesContainer.appendChild(messageItem)
})

channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket
```

We listen for the `"new_msg"` event using `channel.on`, and then append the message body to the DOM. Now let's handle the incoming and outgoing events on the server to complete the picture.

### Incoming Events

We handle incoming events with `handle_in/3`. We can pattern match on the event names, like `"new_msg"`, and then grab the payload that the client passed over the channel. For our chat application, we simply need to notify all other `room:lobby` subscribers of the new message with `broadcast!/3`.

```elixir
defmodule HelloWeb.RoomChannel do
  use Phoenix.Channel

  def join("room:lobby", _message, socket) do
    {:ok, socket}
  end

  def join("room:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_in("new_msg", %{"body" => body}, socket) do
    broadcast!(socket, "new_msg", %{body: body})
    {:noreply, socket}
  end
end
```

`broadcast!/3` will notify all joined clients on this `socket`'s topic and invoke their `handle_out/3` callbacks. `handle_out/3` isn't a required callback, but it allows us to customize and filter broadcasts before they reach each client. By default, `handle_out/3` is implemented for us and simply pushes the message on to the client. Hooking into outgoing events allows for powerful message customization and filtering. Let's see how.

### Intercepting Outgoing Events

We won't implement this for our application, but imagine our chat app allowed users to ignore messages about new users joining a room. We could implement that behavior like this, where we explicitly tell Phoenix which outgoing event we want to intercept and then define a `handle_out/3` callback for those events. (Of course, this assumes that we have an `Accounts` context with an `ignoring_user?/2` function, and that we pass a user in via the `assigns` map). It is important to note that the `handle_out/3` callback will be called for every recipient of a message, so more expensive operations like hitting the database should be considered carefully before being included in `handle_out/3`.

```elixir
intercept ["user_joined"]

def handle_out("user_joined", msg, socket) do
  if Accounts.ignoring_user?(socket.assigns[:user], msg.user_id) do
    {:noreply, socket}
  else
    push(socket, "user_joined", msg)
    {:noreply, socket}
  end
end
```

That's all there is to our basic chat app. Fire up multiple browser tabs and you should see your messages being pushed and broadcasted to all windows!

## Using Token Authentication

When we connect, we'll often need to authenticate the client. Fortunately, this is a 4-step process with [Phoenix.Token](https://hexdocs.pm/phoenix/Phoenix.Token.html).

### Step 1 - Assign a Token in the Connection

Let's say we have an authentication plug in our app called `OurAuth`. When `OurAuth` authenticates a user, it sets a value for the `:current_user` key in `conn.assigns`. Since the `current_user` exists, we can simply assign the user's token in the connection for use in the layout. We can wrap that behavior up in a private function plug, `put_user_token/2`. This could also be put in its own module as well. To make this all work, we just add `OurAuth` and `put_user_token/2` to the browser pipeline.

```elixir
pipeline :browser do
  ...
  plug OurAuth
  plug :put_user_token
end

defp put_user_token(conn, _) do
  if current_user = conn.assigns[:current_user] do
    token = Phoenix.Token.sign(conn, "user socket", current_user.id)
    assign(conn, :user_token, token)
  else
    conn
  end
end
```

Now our `conn.assigns` contains the `current_user` and `user_token`.

### Step 2 - Pass the Token to the JavaScript

Next, we need to pass this token to JavaScript. We can do so inside a script tag in `lib/hello_web/components/layouts/app.html.heex` right above the app.js script, as follows:

```heex
<script>window.userToken = "<%= assigns[:user_token] %>";</script>
<script src={~p"/assets/app.js"}></script>
```

### Step 3 - Pass the Token to the Socket Constructor and Verify

We also need to pass the `:params` to the socket constructor and verify the user token in the `connect/3` function. To do so, edit `lib/hello_web/channels/user_socket.ex`, as follows:

```elixir
def connect(%{"token" => token}, socket, _connect_info) do
  # max_age: 1209600 is equivalent to two weeks in seconds
  case Phoenix.Token.verify(socket, "user socket", token, max_age: 1209600) do
    {:ok, user_id} ->
      {:ok, assign(socket, :current_user, user_id)}
    {:error, reason} ->
      :error
  end
end
```

In our JavaScript, we can use the token set previously when constructing the Socket:

```javascript
let socket = new Socket("/socket", {params: {token: window.userToken}})
```

We used `Phoenix.Token.verify/4` to verify the user token provided by the client. `Phoenix.Token.verify/4` returns either `{:ok, user_id}` or `{:error, reason}`. We can pattern match on that return in a `case` statement. With a verified token, we set the user's id as the value to `:current_user` in the socket. Otherwise, we return `:error`.

### Step 4 - Connect to the socket in JavaScript

With authentication set up, we can connect to sockets and channels from JavaScript.

```javascript
let socket = new Socket("/socket", {params: {token: window.userToken}})
socket.connect()
```

Now that we are connected, we can join channels with a topic:

```javascript
let channel = socket.channel("topic:subtopic", {})
channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket
```

Note that token authentication is preferable since it's transport agnostic and well-suited for long running-connections like channels, as opposed to using sessions or other authentication approaches.

## Fault Tolerance and Reliability Guarantees

Servers restart, networks split, and clients lose connectivity. In order to design robust systems, we need to understand how Phoenix responds to these events and what guarantees it offers.

### Handling Reconnection

Clients subscribe to topics, and Phoenix stores those subscriptions in an in-memory ETS table. If a channel crashes, the clients will need to reconnect to the topics they had previously subscribed to. Fortunately, the Phoenix JavaScript client knows how to do this. The server will notify all the clients of the crash. This will trigger each client's `Channel.onError` callback. The clients will attempt to reconnect to the server using an exponential backoff strategy. Once they reconnect, they'll attempt to rejoin the topics they had previously subscribed to. If they are successful, they'll start receiving messages from those topics as before.

### Resending Client Messages

Channel clients queue outgoing messages into a `PushBuffer`, and send them to the server when there is a connection. If no connection is available, the client holds on to the messages until it can establish a new connection. With no connection, the client will hold the messages in memory until it establishes a connection, or until it receives a `timeout` event. The default timeout is set to 5000 milliseconds. The client won't persist the messages in the browser's local storage, so if the browser tab closes, the messages will be gone.

### Resending Server Messages

Phoenix uses an at-most-once strategy when sending messages to clients. If the client is offline and misses the message, Phoenix won't resend it. Phoenix doesn't persist messages on the server. If the server restarts, unsent messages will be gone. If our application needs stronger guarantees around message delivery, we'll need to write that code ourselves. Common approaches involve persisting messages on the server and having clients request missing messages. For an example, see Chris McCord's Phoenix training: [client code](https://github.com/chrismccord/elixirconf_training/blob/master/web/static/js/app.js#L38-L39) and [server code](https://github.com/chrismccord/elixirconf_training/blob/master/web/channels/document_channel.ex#L13-L19).

## Example Application

To see an example of the application we just built, checkout the project [phoenix_chat_example](https://github.com/chrismccord/phoenix_chat_example).
