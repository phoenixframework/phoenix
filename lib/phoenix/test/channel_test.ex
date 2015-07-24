defmodule Phoenix.ChannelTest do
  @moduledoc """
  Conveniences for testing Phoenix channels.

  In channel tests, we interact with channels via process
  communication, sending and receiving messages. It is also
  common to subscribe to the same topic the channel subscribes
  to, allowing us to assert if a given message was broadcast
  or not.

  ## Channel testing

  To get started, define the module attribute `@endpoint`
  in your test case pointing to your application endpoint.

  Then you can directly `subscribe_and_join/3` topics and
  channels:

      {:ok, _, socket} =
        subscribe_and_join(RoomChannel, "rooms:lobby", %{"id" => 3})

  The function above will subscribe the current test process
  to the "rooms:lobby" topic and start a channel in another
  process. It returns `{:ok, reply, socket}` or `{:error, reply}`.

  Now, in the same way the channel has a socket representing
  communication it will push to the client. Our test has a
  socket representing communication to be pushed to the server.

  For example, we can use the `push/3` function in the test
  to push messages to the channel (it will invoke `handle_in/3`):

      push socket, "my_event", %{"some" => "data"}

  Similarly, we can broadcast messages from the test itself
  on the topic that both test and channel are subscribed to,
  triggering `handle_out/3` on the channel:

      broadcast_from socket, "my_event", %{"some" => "data"}

  > Note only `broadcast_from/3` and `broadcast_from!/3` are
  available in tests to avoid broadcast messages to be resent
  to the test process.

  While the functions above are pushing data to the channel
  (server) we can use `assert_push/3` to verify the channel
  pushed a message to the client:

      assert_push "my_event", %{"some" => "data"}

  Or even assert something was broadcast into pubsub:

      assert_broadcast "my_event", %{"some" => "data"}

  Finally, every time a message is pushed to the channel,
  a reference is returned. We can use this reference to
  assert a particular reply was sent from the server:

      ref = push socket, "counter", %{}
      assert_reply ref, :ok, %{"counter" => 1}

  ## Checking side-effects

  Often one may want to do side-effects inside channels,
  like writing to the database, and verify those side-effects
  during their tests.

  Imagine the following `handle_in/3` inside a channel:

      def handle_in("publish", %{"id" => id}, socket) do
        Repo.get!(Post, id) |> Post.publish() |> Repo.update!()
        {:noreply, socket}
      end

  Because the whole communication is asynchronous, the
  following test would be very brittle:

      push socket, "publish", %{"id" => 3}
      assert Repo.get_by(Post, id: 3, published: true)

  The issue is that we have no guarantees the channel has
  done processing our message after calling `push/3`. The
  best solution is to assert the channel sent us a reply
  before doing any other assertion. First change the
  channel to send replies:

      def handle_in("publish", %{"id" => id}, socket) do
        Repo.get!(Post, id) |> Post.publish() |> Repo.update!()
        {:reply, :ok, socket}
      end

  Then expect them in the test:

      ref = push socket, "publish", %{"id" => 3}
      assert_reply ref, :ok
      assert Repo.get_by(Post, id: 3, published: true)

  ## Leave and close

  This module also provides functions to simulate leaving
  and closing a channel. Once you leave or close a channel,
  because the channel is linked to the test process on join,
  it will crash the test process:

      leave(socket)
      ** (EXIT from #PID<...>) {:shutdown, :leave}

  You can avoid this by unlinking the channel process in
  the test:

      Process.unlink(socket.channel_pid)

  Notice `leave/1` is async, so it will also return a
  reference which you can use to check for a reply:

      ref = leave(socket)
      assert_reply ref, :ok

  On the other hand, close is always sync and it will
  return only after the channel process is guaranteed to
  have been terminated:

      :ok = close(socket)

  This mimics the behaviour existing in clients.
  """

  alias Phoenix.Socket
  alias Phoenix.Socket.Message
  alias Phoenix.Channel.Server

  defmodule NoopSerializer do
    def encode!(message), do: message
    def decode!(message, :text), do: message
  end

  @doc false
  defmacro __using__(_) do
    quote do
      import Phoenix.ChannelTest
    end
  end

  @doc """
  Subscribes to the given topic and joins the channel
  under the given topic and payload.

  By subscribing to the topic, we can use `assert_broadcast/3`
  to verify a message has been sent through the pubsub layer.

  By joining the channel, we can interact with it directly.
  The given channel is joined in a separate process which is
  linked to the test process.

  It returns `{:ok, reply, socket}` or `{:error, reply}`.

  The endpoint is read from the `@endpoint` variable.
  """
  defmacro subscribe_and_join(channel, topic, payload \\ Macro.escape(%{})) do
    quote do
      subscribe_and_join(@endpoint, unquote(channel), unquote(topic), unquote(payload))
    end
  end

  @doc """
  Subscribes to the given topic and joins the channel powered
  by the pubsub server in endpoint under the given topic and
  payload.

  This is useful when you need to join a channel in different
  enpoints, in practice, `subscribe_and_join/3` is recommended.
  """
  def subscribe_and_join(endpoint, channel, topic, payload) do
    unless endpoint do
      raise "module attribute @endpoint not set for subscribe_and_join/3"
    end
    endpoint.subscribe(self(), topic)
    join(endpoint, channel, topic, payload)
  end

  @doc """
  Joins the channel under the given topic and payload.

  The given channel is joined in a separate process
  which is linked to the test process.

  It returns `{:ok, reply, socket}` or `{:error, reply}`.

  The endpoint is read from the `@endpoint` variable.
  """
  defmacro join(channel, topic, payload \\ Macro.escape(%{})) do
    quote do
      join(@endpoint, unquote(channel), unquote(topic), unquote(payload))
    end
  end

  @doc """
  Joins the channel powered by the pubsub server in
  endpoint under the given topic and payload.

  This is useful when you need to join a channel in
  different enpoints, in practice, `join/3` is recommended.
  """
  def join(endpoint, channel, topic, payload) do
    unless endpoint do
      raise "module attribute @endpoint not set for join/3"
    end

    socket = %Socket{serializer: NoopSerializer,
                     transport_pid: self(),
                     endpoint: endpoint,
                     pubsub_server: endpoint.__pubsub_server__(),
                     topic: topic,
                     channel: channel,
                     transport: __MODULE__}

    case Server.join(socket, payload) do
      {:ok, reply, pid} ->
        {:ok, reply, %{socket | channel_pid: pid, joined: true}}
      {:error, _} = error ->
        error
    end
  end

  @doc """
  Pushes a message into the channel.

  The triggers the `handle_in/3` callback in the channel.

  ## Examples

      iex> push socket, "new_message", %{id: 1, content: "hello"}
      :ok

  """
  def push(socket, event, payload \\ %{}) do
    ref = make_ref()
    send(socket.channel_pid,
         %Message{event: event, topic: socket.topic, ref: ref, payload: payload})
    ref
  end

  @doc """
  Emulates the client leaving the channel.
  """
  def leave(socket) do
    ref = make_ref()
    Server.leave(socket.channel_pid, ref)
    ref
  end

  @doc """
  Emulates the client closing the channel.

  Closing channels is synchronous and has a default timeout
  of 5000 miliseconds.
  """
  def close(socket, timeout \\ 5000) do
    Server.close(socket.channel_pid, timeout)
  end

  @doc """
  Broadcast event from pid to all subscribers of the socket topic.

  The test process will not receive the published message. This triggers
  the `handle_out/3` callback in the channel.

  ## Examples

      iex> broadcast_from socket, "new_message", %{id: 1, content: "hello"}
      :ok

  """
  def broadcast_from(socket, event, message) do
    %{pubsub_server: pubsub_server, topic: topic, transport_pid: transport_pid} = socket
    Server.broadcast_from pubsub_server, transport_pid, topic, event, message
  end

  @doc """
  Same as `broadcast_from/3` but raises if broadcast fails.
  """
  def broadcast_from!(socket, event, message) do
    %{pubsub_server: pubsub_server, topic: topic, transport_pid: transport_pid} = socket
    Server.broadcast_from! pubsub_server, transport_pid, topic, event, message
  end

  @doc """
  Asserts the channel has pushed a message back to the client
  with the given event and payload under `timeout`.

  Notice event and payload are patterns. This means one can write:

      assert_push "some_event", %{"data" => _}

  In the assertion above, we don't particularly care about
  the data being sent, as long as something was sent.

  The timeout is in miliseconds and defaults to 100ms.
  """
  defmacro assert_push(event, payload, timeout \\ 100) do
    quote do
      assert_receive %Phoenix.Socket.Message{
                        event: unquote(event),
                        payload: unquote(payload)}, unquote(timeout)
    end
  end

  @doc """
  Asserts the channel has replies to the given message within
  `timeout`.

  Notice status and payload are patterns. This means one can write:

      ref = push channel, "some_event"
      assert_reply ref, :ok, %{"data" => _}

  In the assertion above, we don't particularly care about
  the data being sent, as long as something was replied.

  The timeout is in miliseconds and defaults to 100ms.
  """
  defmacro assert_reply(ref, status, payload \\ Macro.escape(%{}), timeout \\ 100) do
    quote do
      ref = unquote(ref)
      assert_receive %Phoenix.Socket.Reply{
                        status: unquote(status),
                        ref: ^ref,
                        payload: unquote(payload)}, unquote(timeout)
    end
  end

  @doc """
  Asserts the channel has broadcast a message within `timeout`.

  Before asserting anything was broadcast, we must first
  subscribe to the topic of the channel in the test process:

      @endpoint.subscribe(self(), "foo:ok")

  Now we can match on event and payload as patterns:

      assert_broadcast "some_event", %{"data" => _}

  In the assertion above, we don't particularly care about
  the data being sent, as long as something was sent.

  The timeout is in miliseconds and defaults to 100ms.
  """
  defmacro assert_broadcast(event, payload, timeout \\ 100) do
    quote do
      assert_receive %Phoenix.Socket.Broadcast{event: unquote(event),
                                               payload: unquote(payload)}, unquote(timeout)
    end
  end
end
