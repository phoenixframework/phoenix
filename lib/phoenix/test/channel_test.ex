defmodule Phoenix.ChannelTest do
  @moduledoc """
  Conveniences for testing Phoenix channels.

  In channel tests, we interact with channels via process
  communication, sending messages and receiving replies.
  """

  alias Phoenix.Socket
  alias Phoenix.Socket.Message
  alias Phoenix.Channel.Server

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

    socket = %Socket{transport_pid: self(),
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
      assert_receive %Phoenix.Socket.Message{event: unquote(event),
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
      assert_receive %Phoenix.Socket.Reply{status: unquote(status), ref: ^ref,
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
