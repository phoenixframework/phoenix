# Testing Channels

> **Requirement**: This guide expects that you have gone through the [introductory guides](installation.html) and got a Phoenix application [up and running](up_and_running.html).

> **Requirement**: This guide expects that you have gone through the [Introduction to Testing guide](testing.html).

> **Requirement**: This guide expects that you have gone through the [Channels guide](channels.html).

In the Channels guide, we saw that a "Channel" is a layered system with different components. Given this, there would be cases when writing unit tests for our Channel functions may not be enough. We may want to verify that its different moving parts are working together as we expect. This integration testing would assure us that we correctly defined our channel route, the channel module, and its callbacks; and that the lower-level layers such as the PubSub and Transport are configured correctly and are working as intended.

## Generating channels

As we progress through this guide, it would help to have a concrete example we could work off of. Phoenix comes with a Mix task for generating a basic channel and tests. These generated files serve as a good reference for writing channels and their corresponding tests. Let's go ahead and generate our Channel:

```console
$ mix phx.gen.channel Room
* creating lib/hello_web/channels/room_channel.ex
* creating test/hello_web/channels/room_channel_test.exs
* creating test/support/channel_case.ex

The default socket handler - HelloWeb.UserSocket - was not found.

Do you want to create it? [Yn]  
* creating lib/hello_web/channels/user_socket.ex
* creating assets/js/user_socket.js

Add the socket handler to your `lib/hello_web/endpoint.ex`, for example:

    socket "/socket", HelloWeb.UserSocket,
      websocket: true,
      longpoll: false

For the front-end integration, you need to import the `user_socket.js`
in your `assets/js/app.js` file:

    import "./user_socket.js"
```

This creates a channel, its test and instructs us to add a channel route in `lib/hello_web/channels/user_socket.ex`. It is important to add the channel route or our channel won't function at all!

## The ChannelCase

Open up `test/hello_web/channels/room_channel_test.exs` and you will find this:

```elixir
defmodule HelloWeb.RoomChannelTest do
  use HelloWeb.ChannelCase
```

Similar to `ConnCase` and `DataCase`, we now have a `ChannelCase`. All three of them have been generated for us when we started our Phoenix application. Let's take a look at it. Open up `test/support/channel_case.ex`:

```elixir
defmodule HelloWeb.ChannelCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import HelloWeb.ChannelCase

      # The default endpoint for testing
      @endpoint HelloWeb.Endpoint
    end
  end

  setup _tags do
    Hello.DataCase.setup_sandbox(tags)
    :ok
  end
end
```

It is very straight-forward. It sets up a case template that imports all of `Phoenix.ChannelTest` on use. In the `setup` block, it starts the SQL Sandbox, which we discussed in the [Testing contexts guide](testing_contexts.html).

## Subscribe and joining

Now that we know that Phoenix provides with a custom Test Case just for channels and what it
provides, we can move on to understanding the rest of `test/hello_web/channels/room_channel_test.exs`.

First off, is the setup block:

```elixir
setup do
  {:ok, _, socket} =
    HelloWeb.UserSocket
    |> socket("user_id", %{some: :assign})
    |> subscribe_and_join(HelloWeb.RoomChannel, "room:lobby")

  %{socket: socket}
end
```

The `setup` block sets up a `Phoenix.Socket` based on the `UserSocket` module, which you can find at `lib/hello_web/channels/user_socket.ex`. Then it says we want to subscribe and join the `RoomChannel`, accessible as `"room:lobby"` in the `UserSocket`. At the end of the test, we return the `%{socket: socket}` as metadata, so we can reuse it on every test.

In a nutshell, `subscribe_and_join/3` emulates the client joining a channel and subscribes the test process to the given topic. This is a necessary step since clients need to join a channel before they can send and receive events on that channel.

## Testing a synchronous reply

The first test block in our generated channel test looks like:

```elixir
test "ping replies with status ok", %{socket: socket} do
  ref = push(socket, "ping", %{"hello" => "there"})
  assert_reply ref, :ok, %{"hello" => "there"}
end
```

This tests the following code in our `HelloWeb.RoomChannel`:

```elixir
# Channels can be used in a request/response fashion
# by sending replies to requests from the client
def handle_in("ping", payload, socket) do
  {:reply, {:ok, payload}, socket}
end
```

As is stated in the comment above, we see that a `reply` is synchronous since it mimics the request/response pattern we are familiar with in HTTP. This synchronous reply is best used when we only want to send an event back to the client when we are done processing the message on the server. For example, when we save something to the database and then send a message to the client only once that's done.

In the `test "ping replies with status ok", %{socket: socket} do` line, we see that we have the map `%{socket: socket}`. This gives us access to the `socket` in the setup block.

We emulate the client pushing a message to the channel with `push/3`. In the line `ref = push(socket, "ping", %{"hello" => "there"})`, we push the event `"ping"` with the payload `%{"hello" => "there"}` to the channel. This triggers the `handle_in/3` callback we have for the `"ping"` event in our channel. Note that we store the `ref` since we need that on the next line for asserting the reply. With `assert_reply ref, :ok, %{"hello" => "there"}`, we assert that the server sends a synchronous reply `:ok, %{"hello" => "there"}`. This is how we check that the `handle_in/3` callback for the `"ping"` was triggered.

### Testing a Broadcast

It is common to receive messages from the client and broadcast to everyone subscribed to a current topic. This common pattern is simple to express in Phoenix and is one of the generated `handle_in/3` callbacks in our `HelloWeb.RoomChannel`.

```elixir
def handle_in("shout", payload, socket) do
  broadcast(socket, "shout", payload)
  {:noreply, socket}
end
```

Its corresponding test looks like:

```elixir
test "shout broadcasts to room:lobby", %{socket: socket} do
  push(socket, "shout", %{"hello" => "all"})
  assert_broadcast "shout", %{"hello" => "all"}
end
```

We notice that we access the same `socket` that is from the setup block. How handy! We also do the same `push/3` as we did in the synchronous reply test. So we `push` the `"shout"` event with the payload `%{"hello" => "all"}`.

Since the `handle_in/3` callback for the `"shout"` event just broadcasts the same event and payload, all subscribers in the `"room:lobby"` should receive the message. To check that, we do `assert_broadcast "shout", %{"hello" => "all"}`.

**NOTE:** `assert_broadcast/3` tests that the message was broadcast in the PubSub system. For testing if a client receives a message, use `assert_push/3`.

### Testing an asynchronous push from the server

The last test in our `HelloWeb.RoomChannelTest` verifies that broadcasts from the server are pushed to the client. Unlike the previous tests discussed, we are indirectly testing that the channel's `handle_out/3` callback is triggered. By default, `handle_out/3` is implemented for us and simply pushes the message on to the client.

Since the `handle_out/3` event is only triggered when we call `broadcast/3` from our channel, we will need to emulate that in our test. We do that by calling `broadcast_from` or `broadcast_from!`. Both serve the same purpose with the only difference of `broadcast_from!` raising an error when broadcast fails.

The line `broadcast_from!(socket, "broadcast", %{"some" => "data"})` will trigger the `handle_out/3` callback which pushes the same event and payload back to the client. To test this, we do `assert_push "broadcast", %{"some" => "data"}`.

That's it. Now you are ready to develop and fully test real-time applications. To learn more about other functionality provided when testing channels, check out the documentation for [`Phoenix.ChannelTest`](https://hexdocs.pm/phoenix/Phoenix.ChannelTest.html).
