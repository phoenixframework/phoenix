# Testing Channels

As developers we typically value tests since they help to 'future-proof' our applications by
minimizing regression and provide updated documentation. Phoenix recognizes this and helps
make it easier to write tests by providing conveniences for testing its different parts,
including Channels.

In the Channels Guide, we saw that a "Channel" is a layered system with different
components. Given this, there would be cases when writing unit tests for our Channel
functions may not be enough. We may want to verify that its different moving parts
are working together as we expect. This integration testing would assure us that we
correctly defined our channel route, the channel module, and its callbacks; and that
the lower-level layers such as the PubSub and Transport are configured correctly and
are working as intended.


#### The Channel Generator

As we progress through this guide, it would help to have a concrete example we could
work off of. Phoenix comes with a Mix task for generating a basic channel and tests.
These generated files serve as a good reference for writing channels and their
corresponding tests. Let's go ahead and generate our Channel:

```console
$ mix phx.gen.channel Room
* creating lib/hello_web/channels/room_channel.ex
* creating test/hello_web/channels/room_channel_test.exs

Add the channel to your `lib/hello_web/channels/user_socket.ex` handler, for example:

    channel "room:lobby", HelloWeb.RoomChannel
```

This creates a channel, its test and instructs us to add a channel route in
`lib/hello_web/channels/user_socket.ex`. It is important to add the channel route or our
channel won't function at all!

#### The Channel Test Helpers Module

Upon inspecting the file `test/hello_web/channels/room_channel_test.exs`, we see a line that looks like
`use MyAppWeb.ChannelCase`. Note - we assume that our app is named `MyApp` throughout this guide.
Where does this come from?

When we generate a new Phoenix application, a `test/support/channel_case.ex` file is
also generated for us. This file houses the `MyAppWeb.ChannelCase` module which we will
use for all our integration tests for our channels. It automatically imports conveniences
for testing channels.

Some of the helper functions provided there are for triggering callback functions in our
channel. The others are there to provide us with special assertions that apply only to channels.

If we need to add our own helper function that we would only use in channel tests, we
would add it to `MyAppWeb.ChannelCase` by defining it there and ensuring `MyAppWeb.ChannelCase`
is imported every time it is `use`d. For example:

```elixir
defmodule MyAppWeb.ChannelCase do
  ...

  using do
    quote do
      ...
      import MyAppWeb.ChannelCase
    end
  end

  def a_channel_test_helper() do
    # code here
  end
end
```


#### The Setup Block

Now that we know that Phoenix provides with a custom Test Case just for channels and what it
provides, we can move on to understanding the rest of `test/hello_web/channelsj/room_channel_test.exs`.

First off, is the setup block:

```elixir
setup do
  {:ok, _, socket} =
    socket("user_id", %{some: :assign})
    |> subscribe_and_join(RoomChannel, "room:lobby")

  {:ok, socket: socket}
end
```

The `setup/2` macro comes with `ExUnit`which comes out of the box with Elixir. The `do` block
passed to `setup/2` will get run for each of our tests. Note the line `{:ok, socket: socket}`.
That line ensures that the `socket` from `subscribe_and_join/3` will be accessible to all
our tests. In this way, we won't need to call `subscribe_and_join/3` for every test block we
create.

`subscribe_and_join/3` emulates the client joining a channel and subscribes the test process
to the given topic. This is a necessary step since clients need to join a channel before they
can send and receive events on that channel.


#### Testing a Synchronous Reply

The first test block in our generated channel test looks like:

```elixir
test "ping replies with status ok", %{socket: socket} do
  ref = push socket, "ping", %{"hello" => "there"}
  assert_reply ref, :ok, %{"hello" => "there"}
end
```

This tests the following code in our `MyAppWeb.RoomChannel`:

```elixir
# Channels can be used in a request/response fashion
# by sending replies to requests from the client
def handle_in("ping", payload, socket) do
  {:reply, {:ok, payload}, socket}
end
```

As is stated in the comment above, we see that a `reply` is synchronous since it mimics the request/
response pattern we are familiar with in HTTP. This synchronous reply is best used when we only
want to send an event back to the client when we are done processing the message on the server.
For example, when we save something to the database and then send a message to the client only once
that's done.

In the `test "ping replies with status ok", %{socket: socket} do` line, we see that we have the
map `%{socket: socket}`. This gives us access to the `socket` in the setup block.

We emulate the client pushing a message to the channel with `push/3`. In the line
`ref = push socket, "ping", %{"hello" => "there"}`, we push the event `"ping"` with the payload
`%{"hello" => "there"}` to the channel. This triggers the `handle_in/3` callback we have for the
`"ping"` event in our channel. Note that we store the `ref` since we need that on the next line for
asserting the reply. With `assert_reply ref, :ok, %{"hello" => "there"}`, we assert that the
server sends a synchronous reply `:ok, %{"hello" => "there"}`. This is how we check that the
`handle_in/3` callback for the `"ping"` was triggered.


#### Testing a Broadcast

It is common to receive messages from the client and broadcast to everyone subscribed to a
current topic. This common pattern is simple to express in Phoenix and is one of the generated
`handle_in/3` callbacks in our `MyAppWeb.RoomChannel`.

```elixir
def handle_in("shout", payload, socket) do
  broadcast socket, "shout", payload
  {:noreply, socket}
end
```

Its corresponding test looks like:

```elixir
test "shout broadcasts to room:lobby", %{socket: socket} do
  push socket, "shout", %{"hello" => "all"}
  assert_broadcast "shout", %{"hello" => "all"}
end
```

We notice that we access the same `socket` that is from the setup block. How handy! We also do the
same `push/3` as we did in the synchronous reply test. So we `push` the `"shout"` event with the
payload `%{"hello" => "all"}`.

Since the `handle_in/3` callback for the `"shout"` event just broadcasts the same event and payload,
all subscribers in the `"room:lobby"` should receive the message. To check that, we do
`assert_broadcast "shout", %{"hello" => "all"}`.


#### Testing an Asynchronous Push from the Server

The last test in our `MyAppWeb.RoomChannelTest` verifies that broadcasts from the server are pushed
to the client. Unlike the previous tests discussed, we are indirectly testing that our channel's
`handle_out/3` callback is triggered. This `handle_out/3` is defined in our `MyApp.RoomChannel` as:

```elixir
def handle_out(event, payload, socket) do
  push socket, event, payload
  {:noreply, socket}
end
```

Since the `handle_out/3` event is only triggered when we call `broadcast/3` from our channel,
we will need to emulate that in our test. We do that by calling `broadcast_from` or
`broadcast_from!`. Both serve the same purpose with the only difference of `broadcast_from!`
raising an error when broadcast fails.

The line `broadcast_from! socket, "broadcast", %{"some" => "data"}` will trigger our `handle_out/3`
callback above which pushes the same event and payload back to the client. To test this, we do
`assert_push "broadcast", %{"some" => "data"}`.


#### Wrap-up

In this guide we tackled all the special assertions that comes with `MyAppWeb.ConnCase` and some of
the functions provided that help you test channels by triggering its callbacks. We found
the API for testing channels is largely consistent with the API for Phoenix Channels which makes
it easy to work with.

If interested in learning more about the helpers provided by `MyAppWeb.ChannelCase`, check out the
documentation for [`Phoenix.ChannelTest`](https://hexdocs.pm/phoenix/Phoenix.ChannelTest.html) which is the module that defines those functions.
