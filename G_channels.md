Channels are a really exciting and powerful part of Phoenix, one that allows us to easily add soft-realtime features to our applications. Channels are based on a simple idea - sending and receiving messages. Senders broadcast messages about topics. Receivers subscribe to topics so that they can receive those messages. Senders and receivers can switch roles on the same topic at any time.

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

Each Channel will implement one or more clauses of each of these four callback functions - `join/3`, `leave/2`, `handle_in/3`, and `handle_out/3`.

- PubSub

The `Phoenix.PubSub` module contains functions which are the nuts and bolts of organizing Channel communication - subscribing to topics, unsubscribing from topics, and broadcasting messages on a topic.

It is worth noting that this module is intended for Phoenix's internal use. Channels use it under the hood to do much of their work. As end users, we shouldn't have any need to use PubSub directly.

- Sockets

The `Phoenix.Socket` module defines functions for authorizing and de-authorizing topics for a Channel. It also defines a struct with the following keys which holds state representing the socket connection. From the [Phoenix.Socket docs](http://hexdocs.pm/phoenix/Phoenix.Socket.html):
  - `pid` - The Pid of the socket's transport process
  - `topic` - The string topic, ie `"rooms:123"`
  - `router` - The router module where this socket originated
  - `authorized` - The boolean authorization status, default `false`
  - `assigns` - The map of socket assigns, default: `%{}`
  - `transport` - The socket's Transport, ie: `Phoenix.Transports.WebSocket`

- Messages

The `Phoenix.Socket.Message` module defines a struct with the following keys which denotes a valid message. From the [Phoenix.Socket.Message docs](http://hexdocs.pm/phoenix/Phoenix.Socket.Message.html).
  - `topic` - The String topic or topic:subtopic pair namespace, ie “messages”, “messages:123”
  - `event` - The String event name, ie “join”
  - `payload` - The String JSON message payload

- Topics

Topics are currently used only as identifiers - names that the various layers use in order to make sure messages end up in the right place. As we saw above, topics can use wildcards. This allows for a useful "topic:subtopic" convention.

- Transports

The transport layer is where the rubber meets the road. The `Phoenix.Channel.Transport` module handles all the message dispatching into and out of a Channel.

- Transport Adapters

The default transport mechanism is via WebSockets which will fall back to LongPolling if WebSockets are not available/working. Other transport adapters are possible, and indeed, we can write our own if we follow the adapter contract. Please see `Phoenix.Transports.WebSocket` for an example.

- Client Libraries

Phoenix currently ships with it's own JavaScript client. There is a Swift client under construction, and an Android client would be great if anyone finds that project exciting and would like to write one.

#### A Quick Test Run
Before we go in-depth into Channels, let's do a quick test to get a feeling for how this works. We'll broadcast a simple message to ourselves in iex on the topic `"rooms:demo"`. Let's shut down our application if it is already running by hitting `ctrl-c` twice in the iex session. Then let's run `$ iex -S mix` at the root of our application.

Normally, we would not work with the `Phoenix.PubSub` module directly. Since we won't be handling external requests, and since we want to keep this as simple as possible, we will be using it here.

Before we begin, let's make see if we have any subscribers for the topic we'll use for demo purposes.

```console
iex(1)> Phoenix.PubSub.subscribers("rooms:demo")
[]
```
Nobody there yet so let's subscribe ourselves and check again.

```console
iex(2)> Phoenix.PubSub.subscribe(self, "rooms:demo")
:ok
iex(3)> Phoenix.PubSub.subscribers("rooms:demo")
[#PID<0.142.0>]
```
Great, now we will receive any messages broadcast to this topic.

Let's check that by broadcasting a message to see if we receive it.

```console
iex(4)> Phoenix.PubSub.broadcast("rooms:demo", {:message, "It Works!"})
:ok
iex(5)> Process.info(self)[:messages]
[message: "It Works!"]
```
Note that we check our own process info for messages.

We can also unsubscribe ourselves from a topic.

```console
iex(6)> Phoenix.PubSub.unsubscribe(self, "rooms:demo")
:ok
iex(7)> Phoenix.PubSub.subscribers("rooms:demo")
[]
```
This is the simplest possible demonstration of sending messages about topics. Great, so let's dig a little deeper.

### Let's Build a Channel

The first thing we are going to need is a route, so let's add a channel route to our `web/router.ex` file like this.

```elixir
socket "/ws", HelloPhoenix do
  channel "foods:*", FoodChannel
end
```
Again, please see the [Routing Guide](http://www.phoenixframework.org/docs/routing) for more information about channel routes.

Next, we'll need a Channel, so let's create an empty one for now at `web/channels/food_channel.ex`.

```elixir
defmodule HelloPhoenix.FoodChannel do
  use Phoenix.Channel
end
```

#### Joining a Channel Topic
In order to broadcast messages, senders need to join a Channel on a Topic. We facilitate that with the `join/3` function. `join/3` is an authorization mechanism. If we believe the sender should be authorized, we return `{:ok, socket}`. If not, we return `{:error, socket, :unauthorized}`.

The three arguments to `join/3` are a topic, a message, and a socket. Since we're just experimenting, let's return `{:ok, socket}` no matter what. And since we aren't going to use the `message` argument for now, let's prepend it with an underscore to avoid compiler warnings.

```elixir
defmodule HelloPhoenix.FoodChannel do
  use Phoenix.Channel

  def join("foods:all", _message, socket) do
    {:ok, socket}
  end
end
```
Let's explore this a little bit in iex. Before we do anything, we should check to see if we have any subscribers on our "foods:all" topic.

```conole
ex(1)> Phoenix.PubSub.subscribers "foods:all"
[]
```
Ok, nobody has subscribed yet. What we're going to do is to dispatch a message to our `FoodChannel` which will be handled by the `join/3` function and authorize our socket.

The first thing we need to do is create a socket. This one will work.

```console
iex(2)> socket = %Phoenix.Socket{pid: self, router: HelloPhoenix.Router, topic: "foods:all", assigns: [], transport: Phoenix.Transports.WebSocket}

%Phoenix.Socket{assigns: [], authorized: false, pid: #PID<0.142.0>,
  router: HelloPhoenix.Router, topic: "foods:all",
  transport: Phoenix.Transports.WebSocket}
```
There are two things to note here. The first is that we really do need to specify a transport, otherwise this won't work. WebSocket is a great choice. Also note that this socket is not currently authorized - `authorized: false` is the default.

Here comes the magic part. We can dispatch a message to the app from inside the app using `dispatch/4`. By using `dispatch/4`, we mimic the full request cycle - from the router through all the layers we talked about above - ending up in our `FoodChannel.join/3` function. The arguments for `dispatch/4` are a socket, a topic string, an event string, and a message which just needs to be a map. Here, we'll use an empty map for simplicity.

In order to trigger the `join/3` function, we send the "join" event, and the topic is still "foods:all".

```console
iex(4)> {:ok, socket} = Phoenix.Channel.Transport.dispatch socket, "foods:all", "join", %{}

{:ok,
  %Phoenix.Socket{assigns: [], authorized: true, pid: #PID<0.142.0>,
    router: HelloPhoenix.Router, topic: "foods:all",
    transport: Phoenix.Transports.WebSocket}}
```
Notice that from the response, we can tell that this socket is now authorized for the "foods:all" topic. This is the result of returning `{:ok, socket}` from the `join/3` function. We also took care to re-bind the socket so that if we need it again in subsequent steps, it will be authorized on this topic for this channel.

The question is, did it really work? Were we subscribed to the topic? Let's find out using `subscribers/1`.

```console
iex(5)> Phoenix.PubSub.subscribers "foods:all"
[#PID<0.142.0>]
iex(6)> self
#PID<0.142.0>
```
Yes, we clearly are subscribed to the "foods:all" topic.

Let's take a look at what happens when we try to join a topic that does not authenticate us. We'll need an additional clause of the `join/3` function in our `FoodChannel`, like this.

```elixir
defmodule HelloPhoenix.FoodChannel do
  use Phoenix.Channel

  def join("foods:all", _message, socket) do
    {:ok, socket}
  end

  def join("foods:forbidden", _message, socket) do
    {:error, socket, :unauthorized}
  end
end
```
This time, we hard-code the return value of `{:error, socket, :unauthorized}`, so no attempt to join this topic should ever succeed.

We'll use a new socket for this, one with the new topic we are matching on as well as the default value for `authorized`, which is false.

```console
iex(1)> new_socket = %Phoenix.Socket{pid: self, router: HelloPhoenix.Router, topic: "foods:forbidden", assigns: [], transport: Phoenix.Transports.WebSocket}

%Phoenix.Socket{assigns: [], authorized: false, pid: #PID<0.142.0>,
  router: HelloPhoenix.Router, topic: "foods:forbidden",
  transport: Phoenix.Transports.WebSocket}
```
When we dispatch again on our `new_socket`, we see that we get an error and that the socket is not authorized to join that topic on this channel.

```console
iex(3)> {:error, socket, :unauthorized} = Phoenix.Channel.Transport.dispatch new_socket, "foods:forbidden", "join", %{}

{:error,
  %Phoenix.Socket{assigns: [], authorized: false, pid: #PID<0.142.0>,
    router: HelloPhoenix.Router, topic: "foods:forbidden",
    transport: Phoenix.Transports.WebSocket}, :unauthorized}
```
Just to make sure, let's check the subscribers again.

```cosole
iex(4)> Phoenix.PubSub.subscribers "foods:forbidden"
[]
```
Of course, we can pattern match on more than just hard-coded topic strings. This clause of `join/3` works as well. Have fun and experiment with it as we have above.

```elixir
def join("foods:" <> _some_food_string, _message, socket) do
  {:ok, socket}
end
```

#### Leaving a Channel Topic

Once we can join topics on channels, the next step is being able to leave them. For this, we need the `leave/2` function defined in our `FoodChannel`. In a fresh iex session, let's join two topics on our `FoodChannel` using the steps above. For our example, let's use "foods:all" and "foods:delightful".

Before we go further, let's make sure we really are subscribed to those topics.

```console
iex(10)> self
#PID<0.151.0>

iex(11)> Phoenix.PubSub.subscribers "foods:all"
[#PID<0.151.0>]

iex(12)> Phoenix.PubSub.subscribers "foods:delightful"
[#PID<0.151.0>]
```
Great, now let's add our `leave/2` function. For our purposes, we have no restrictions on leaving a topic, so let's always return `{:ok, socket}`.

```elixir
def leave(_reason, socket) do
  {:ok, socket}
end
```
Great, now let's call the `dispatch/4` function again using the "foods:all" topic and the "leave" event. Again, this request will make it's way from the router all the way to the `leave/2` function in our `FoodChannel`.

```console
iex(22)> {:leave, socket} = Phoenix.Channel.Transport.dispatch socket, "foods:all", "leave", %{}

{:leave,
  %Phoenix.Socket{assigns: [], authorized: false, pid: #PID<0.151.0>,
    router: HelloPhoenix.Router, topic: "foods:all",
    transport: Phoenix.Transports.WebSocket}}
```
Notice that the request processing didn't stop with the return of `leave/2`. The final tuple we get back is `{:leave, socket}` instead of `{:ok, socket}`. The socket also is no longer authorized for the "foods:all" topic for this channel.

Did it really unsubscribe us? Let's see.

```console
iex(23)> Phoenix.PubSub.subscribers "foods:all"
[]
```
Indeed it did.

And, of course, we are still subscribed to the "foods:delightful" topic.

```console
iex(24)> Phoenix.PubSub.subscribers "foods:delightful"
[#PID<0.151.0>]
```

#### Incoming Messages

Joining and leaving topics are not the most exciting things in and of themselves, but they are necessary steps toward actually sending messages. That's what we're going to look at now.

Incoming events are handled by the `handle_in/3` function, so let's add one to our `FoodChannel` module. The arguments are an event string, a map for the message, and a socket.

```elixir
def handle_in("new:msg", message, socket) do
  broadcast socket, "new:msg", message
end
```
In this clause of the `handle_in/3` function, we are being very specific about the event we will respond to. Only `"new:msg"` will match.

We can respond to incoming events in any way we like, including just returning `{:ok, socket}` if we choose to. More commonly, we want to pass along the event coming into the server to one or more subscribers to the topic. For that, we have a choice of using either the `broadcast/3` or `reply/3` functions. `broadcast/3` will send the message to every subscriber to the topic, while `reply/3` will only reply back to the sender.

Both `broadcast/3` and `reply/3` return `{:ok, socket}`, so we don't need to add them here. If neither of those functions are the last one we call in `handle_in/3`, then we would need to add `{:ok, socket}` as the last line so that it would be our return value.

Let's see this in action. First, let's make sure we have joined the `"foods:all`" topic on the `FoodChannel`.

```console
iex(7)> Phoenix.PubSub.subscribers "foods:all"
[#PID<0.142.0>]
```
If your pid isn't in the subscribers list, please follow the steps in "Joining a Channel Topic" above.

Also, let's take a second to check the `socket` to make sure it is authorized for our topic using `authorized?/2`.

```console
iex(8)> Phoenix.Socket.authorized?(socket, "foods:all")
true
```
Note: If this comes back false, it is probably due to not rebinding `socket` after dispatching to the `join` event above, like this: `{:ok, socket} = Phoenix.Channel.Transport.dispatch socket, "foods:all", "join", message`.

If the socket is not authorized for the topic, we can fix that with the `authorize/2` function.

```console
iex(9)> Phoenix.Socket.authorize(socket, "foods:all")

%Phoenix.Socket{assigns: [], authorized: true, pid: #PID<0.142.0>,
  router: HelloPhoenix.Router, topic: "foods:all",
  transport: Phoenix.Transports.WebSocket}
```
Now that our socket is authorized, we can dispatch a message. This works exactly the same way that we have used it up to now, passing in a socket, topic, event, and message.

```console
iex(10)> {:ok, socket} = Phoenix.Channel.Transport.dispatch socket, "foods:all", "new:msg", %{say: "Success!"}

{:ok,
  %Phoenix.Socket{assigns: [], authorized: true, pid: #PID<0.142.0>,
    router: HelloPhoenix.Router, topic: "foods:all",
    transport: Phoenix.Transports.WebSocket}}
```
Note: Again, the message must be a map. Any other type of value will throw an error.

Now let's see if our message has been delivered.

```console
iex(11)> Process.info(self)[:messages]

[socket_broadcast: %Phoenix.Socket.Message{event: "new:msg",
payload: %{say: "Success!"}, topic: "foods:all"}]
```
And it worked.

We can use pattern matching to offer more flexibility for the events that `handle_in/3` will respond to. As an experiment, try creating a new clause of `handle_in/3` like the one below and dispatch a message to `"foods:all"` with a `"new:burrito"` event.

```elixir
def handle_in(event = "new:" <> _some_food, message, socket) do
  reply socket, event, message
end
```
Of course, we could write a clause that is even more general, one which will respond to any event, like the one below.

```elixir
def handle_in(event, message, socket) do
  broadcast socket, event, message
end
```

#### Outgoing Messages

We handle outgoing messages with `handle_out/3` in very much the same way as we handle incoming messages with `handle_in/3`. The arguments are the same. Our choices of using `broadcast/3` or `reply/3` is the same. We do get some extra flexibility to customize the behavior per subscriber, if we choose to use it.

Here's an example from the [Phoenix Channel docs](http://hexdocs.pm/phoenix/Phoenix.Channel.html). Imagine we had a chat application in which we allowed users to ignore messages about new users joining a room. We could implement that behavior like this. (Of course, this assumes that we have a `User` model with an `ignorning?/2` function, and that we pass a user in via the `assigns` map.)

```elixir
def handle_out("user:joined", msg, socket) do
  if User.ignoring?(socket.assigns[:user], msg.user_id) do
    {:ok, socket}
  else
    reply socket, "user:joined", msg
  end
end
```
Similarly, imagine we had a `MagicEightBall` module with a `prediction/0` function that returned a random prediction. We could customize each message from `handle_out/3` with a prediction like this.

```elixir
def handle_out("new:message", message, socket) do
  reply socket, "new:message", Dict.merge(message, magic_8_ball_sez: MagicEightBall.prediction)
end
```

#### Example Application

So far, we've only explored Channels through iex sessions. This was intentional; it is easier and quicker to get to the heart of the functionality in iex without having to build a whole client layer to see behavior. Now that we have seen how channels works, it might be useful to see an example application. There is a great one [here](https://github.com/chrismccord/phoenix_chat_example).
