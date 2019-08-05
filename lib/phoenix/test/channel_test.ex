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

  Then you can directly create a socket and
  `subscribe_and_join/4` topics and channels:

      {:ok, _, socket} =
        socket(UserSocket, "user:id", %{some_assigns: 1})
        |> subscribe_and_join(RoomChannel, "room:lobby", %{"id" => 3})

  You usually want to set the same ID and assigns your
  `UserSocket.connect/3` callback would set. Alternatively,
  you can use the `connect/3` helper to call your `UserSocket.connect/3`
  callback and initialize the socket with the socket id:

      {:ok, socket} = connect(UserSocket, %{"some" => "params"}, %{})
      {:ok, _, socket} = subscribe_and_join(socket, "room:lobby", %{"id" => 3})

  Once called, `subscribe_and_join/4` will subscribe the
  current test process to the "room:lobby" topic and start a
  channel in another process. It returns `{:ok, reply, socket}`
  or `{:error, reply}`.

  Now, in the same way the channel has a socket representing
  communication it will push to the client. Our test has a
  socket representing communication to be pushed to the server.

  For example, we can use the `push/3` function in the test
  to push messages to the channel (it will invoke `handle_in/3`):

      push(socket, "my_event", %{"some" => "data"})

  Similarly, we can broadcast messages from the test itself
  on the topic that both test and channel are subscribed to,
  triggering `handle_out/3` on the channel:

      broadcast_from(socket, "my_event", %{"some" => "data"})

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

      ref = push(socket, "counter", %{})
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

      push(socket, "publish", %{"id" => 3})
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

      ref = push(socket, "publish", %{"id" => 3})
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

  To assert that your channel closes or errors asynchronously,
  you can monitor the channel process with the tools provided
  by Elixir, and wait for the `:DOWN` message.
  Imagine an implementation of the `handle_info/2` function
  that closes the channel when it receives `:some_message`:

      def handle_info(:some_message, socket) do
        {:stop, :normal, socket}
      end

  In your test, you can assert that the close happened by:

      Process.monitor(socket.channel_pid)
      send(socket.channel_pid, :some_message)
      assert_receive {:DOWN, _, _, _, :normal}

  """

  alias Phoenix.Socket
  alias Phoenix.Socket.{Broadcast, Message, Reply}
  alias Phoenix.Channel.Server

  defmodule NoopSerializer do
    @behaviour Phoenix.Socket.Serializer
    @moduledoc false

    def fastlane!(%Broadcast{} = msg) do
      %Message{
        topic: msg.topic,
        event: msg.event,
        payload: msg.payload
      }
    end

    def encode!(%Reply{} = reply), do: reply
    def encode!(%Message{} = msg), do: msg
    def decode!(message, _opts), do: message
  end

  @doc false
  defmacro __using__(_) do
    quote do
      import Phoenix.ChannelTest
    end
  end

  @doc """
  Builds a socket for the given `socket_module`.

  The socket is then used to subscribe and join channels.
  Use this function when you want to create a blank socket
  to pass to functions like `UserSocket.connect/3`.

  Otherwise, use `socket/3` if you want to build a socket with
  existing id and assigns.

  ## Examples

      socket(MyApp.UserSocket)

  """
  defmacro socket(socket_module) do
    build_socket(socket_module, nil, [], __CALLER__)
  end

  @doc """
  Builds a socket for the given `socket_module` with given id and assigns.

  ## Examples

      socket(MyApp.UserSocket, "user_id", %{some: :assign})

  """
  defmacro socket(socket_module, socket_id, socket_assigns) do
    build_socket(socket_module, socket_id, socket_assigns, __CALLER__)
  end

  defp build_socket(socket, id, assigns, caller) do
    if endpoint = Module.get_attribute(caller.module, :endpoint) do
      quote do
        %Socket{
          assigns: Enum.into(unquote(assigns), %{}),
          endpoint: unquote(endpoint),
          handler: unquote(socket || first_socket!(endpoint)),
          id: unquote(id),
          pubsub_server: unquote(endpoint).__pubsub_server__(),
          serializer: NoopSerializer,
          transport: :channel_test,
          transport_pid: self()
        }
      end
    else
      raise "module attribute @endpoint not set for socket/2"
    end
  end

  @doc false
  defmacro socket() do
    IO.warn "Phoenix.ChannelTest.socket/0 is deprecated, please call socket/1 instead"
    build_socket(nil, nil, [], __CALLER__)
  end

  @doc false
  defmacro socket(id, assigns) do
    IO.warn "Phoenix.ChannelTest.socket/2 is deprecated, please call socket/3 instead"
    build_socket(nil, id, assigns, __CALLER__)
  end

  # TODO v2: Remove this alongside the deprecations above.
  defp first_socket!(endpoint) do
    case endpoint.__sockets__ do
      [] -> raise ArgumentError, "#{inspect endpoint} has no socket declaration"
      [{_, socket, _} | _] -> socket
    end
  end

  @doc """
  Initiates a transport connection for the socket handler.

  Useful for testing UserSocket authentication. Returns
  the result of the handler's `connect/3` callback.
  """
  defmacro connect(handler, params, connect_info \\ quote(do: %{})) do
    if endpoint = Module.get_attribute(__CALLER__.module, :endpoint) do
      quote do
        unquote(__MODULE__).__connect__(unquote(endpoint), unquote(handler), unquote(params), unquote(connect_info))
      end
    else
      raise "module attribute @endpoint not set for socket/2"
    end
  end

  @doc false
  def __connect__(endpoint, handler, params, connect_info) do
    map = %{
      endpoint: endpoint,
      transport: :channel_test,
      options: [serializer: [{NoopSerializer, "~> 1.0.0"}]],
      params: __stringify__(params),
      connect_info: connect_info
    }

    with {:ok, state} <- handler.connect(map),
         {:ok, {_, socket}} = handler.init(state),
         do: {:ok, socket}
  end

  @doc "See `subscribe_and_join!/4`."
  def subscribe_and_join!(%Socket{} = socket, topic) when is_binary(topic) do
    subscribe_and_join!(socket, nil, topic, %{})
  end

  @doc "See `subscribe_and_join!/4`."
  def subscribe_and_join!(%Socket{} = socket, topic, payload)
      when is_binary(topic) and is_map(payload) do
    subscribe_and_join!(socket, nil, topic, payload)
  end

  @doc """
  Same as `subscribe_and_join/4`, but returns either the socket
  or throws an error.

  This is helpful when you are not testing joining the channel
  and just need the socket.
  """
  def subscribe_and_join!(%Socket{} = socket, channel, topic, payload \\ %{})
      when is_atom(channel) and is_binary(topic) and is_map(payload) do
    case subscribe_and_join(socket, channel, topic, payload) do
      {:ok, _, socket} -> socket
      {:error, error}  -> raise "could not join channel, got error: #{inspect(error)}"
    end
  end

  @doc "See `subscribe_and_join/4`."
  def subscribe_and_join(%Socket{} = socket, topic) when is_binary(topic) do
    subscribe_and_join(socket, nil, topic, %{})
  end

  @doc "See `subscribe_and_join/4`."
  def subscribe_and_join(%Socket{} = socket, topic, payload)
      when is_binary(topic) and is_map(payload) do
    subscribe_and_join(socket, nil, topic, payload)
  end

  @doc """
  Subscribes to the given topic and joins the channel
  under the given topic and payload.

  By subscribing to the topic, we can use `assert_broadcast/3`
  to verify a message has been sent through the pubsub layer.

  By joining the channel, we can interact with it directly.
  The given channel is joined in a separate process which is
  linked to the test process.

  If no channel module is provided, the socket's handler is used to
  lookup the matching channel for the given topic.

  It returns `{:ok, reply, socket}` or `{:error, reply}`.
  """
  def subscribe_and_join(%Socket{} = socket, channel, topic, payload \\ %{})
      when is_atom(channel) and is_binary(topic) and is_map(payload) do
    socket.endpoint.subscribe(topic)
    join(socket, channel, topic, payload)
  end

  @doc "See `join/4`."
  def join(%Socket{} = socket, topic) when is_binary(topic) do
    join(socket, nil, topic, %{})
  end

  @doc "See `join/4`."
  def join(%Socket{} = socket, topic, payload) when is_binary(topic) and is_map(payload) do
    join(socket, nil, topic, payload)
  end

  @doc """
  Joins the channel under the given topic and payload.

  The given channel is joined in a separate process
  which is linked to the test process.

  It returns `{:ok, reply, socket}` or `{:error, reply}`.
  """
  def join(%Socket{} = socket, channel, topic, payload \\ %{})
      when is_atom(channel) and is_binary(topic) and is_map(payload) do
    message = %Message{
      event: "phx_join",
      payload: __stringify__(payload),
      topic: topic,
      ref: System.unique_integer([:positive])
    }

    {channel, opts} =
      if channel do
        {channel, []}
      else
        match_topic_to_channel!(socket, topic)
      end

    case Server.join(socket, channel, message, opts) do
      {:ok, reply, pid} ->
        Process.link(pid)
        {:ok, reply, Server.socket(pid)}
      {:error, _} = error ->
        error
    end
  end

  @doc """
  Pushes a message into the channel.

  The triggers the `handle_in/3` callback in the channel.

  ## Examples

      iex> push(socket, "new_message", %{id: 1, content: "hello"})
      reference

  """
  @spec push(Socket.t, String.t, map()) :: reference()
  def push(socket, event, payload \\ %{}) do
    ref = make_ref()
    send(socket.channel_pid,
         %Message{event: event, topic: socket.topic, ref: ref, payload: __stringify__(payload)})
    ref
  end

  @doc """
  Emulates the client leaving the channel.
  """
  @spec leave(Socket.t) :: reference()
  def leave(socket) do
    push(socket, "phx_leave", %{})
  end

  @doc """
  Emulates the client closing the socket.

  Closing socket is synchronous and has a default timeout
  of 5000 milliseconds.
  """
  def close(socket, timeout \\ 5000) do
    Server.close(socket.channel_pid, timeout)
  end

  @doc """
  Broadcast event from pid to all subscribers of the socket topic.

  The test process will not receive the published message. This triggers
  the `handle_out/3` callback in the channel.

  ## Examples

      iex> broadcast_from(socket, "new_message", %{id: 1, content: "hello"})
      :ok

  """
  def broadcast_from(socket, event, message) do
    %{pubsub_server: pubsub_server, topic: topic, transport_pid: transport_pid} = socket
    Server.broadcast_from pubsub_server, transport_pid, topic, event, message
  end

  @doc """
  Same as `broadcast_from/3`, but raises if broadcast fails.
  """
  def broadcast_from!(socket, event, message) do
    %{pubsub_server: pubsub_server, topic: topic, transport_pid: transport_pid} = socket
    Server.broadcast_from! pubsub_server, transport_pid, topic, event, message
  end

  @doc """
  Asserts the channel has pushed a message back to the client
  with the given event and payload within `timeout`.

  Notice event and payload are patterns. This means one can write:

      assert_push "some_event", %{"data" => _}

  In the assertion above, we don't particularly care about
  the data being sent, as long as something was sent.

  The timeout is in milliseconds and defaults to the `:assert_receive_timeout`
  set on the `:ex_unit` application (which defaults to 100ms).

  **NOTE:** Because event and payload are patterns, they will be matched.  This
  means that if you wish to assert that the received payload is equivalent to
  an existing variable, you need to pin the variable in the assertion
  expression.

  Good:

      expected_payload = %{foo: "bar"}
      assert_push "some_event", ^expected_payload

  Bad:

      expected_payload = %{foo: "bar"}
      assert_push "some_event", expected_payload
      # The code above does not assert the payload matches the described map.

  """
  defmacro assert_push(event, payload, timeout \\ Application.fetch_env!(:ex_unit, :assert_receive_timeout)) do
    quote do
      assert_receive %Phoenix.Socket.Message{
                        event: unquote(event),
                        payload: unquote(payload)}, unquote(timeout)
    end
  end

  @doc """
  Asserts the channel has not pushed a message to the client
  matching the given event and payload within `timeout`.

  Like `assert_push`, the event and payload are patterns.

  The timeout is in milliseconds and defaults to the `:refute_receive_timeout`
  set on the `:ex_unit` application (which defaults to 100ms).
  Keep in mind this macro will block the test by the
  timeout value, so use it only when necessary as overuse
  will certainly slow down your test suite.
  """
  defmacro refute_push(event, payload, timeout \\ Application.fetch_env!(:ex_unit, :refute_receive_timeout)) do
    quote do
      refute_receive %Phoenix.Socket.Message{
                        event: unquote(event),
                        payload: unquote(payload)}, unquote(timeout)
    end
  end

  @doc """
  Asserts the channel has replied to the given message within
  `timeout`.

  Notice status and payload are patterns. This means one can write:

      ref = push(channel, "some_event")
      assert_reply ref, :ok, %{"data" => _}

  In the assertion above, we don't particularly care about
  the data being sent, as long as something was replied.

  The timeout is in milliseconds and defaults to the `:assert_receive_timeout`
  set on the `:ex_unit` application (which defaults to 100ms).
  """
  defmacro assert_reply(ref, status, payload \\ Macro.escape(%{}), timeout \\ Application.fetch_env!(:ex_unit, :assert_receive_timeout)) do
    quote do
      ref = unquote(ref)
      assert_receive %Phoenix.Socket.Reply{
                        ref: ^ref,
                        status: unquote(status),
                        payload: unquote(payload)}, unquote(timeout)
    end
  end

  @doc """
  Asserts the channel has not replied with a matching payload within
  `timeout`.

  Like `assert_reply`, the event and payload are patterns.

  The timeout is in milliseconds and defaults to the `:refute_receive_timeout`
  set on the `:ex_unit` application (which defaults to 100ms).
  Keep in mind this macro will block the test by the
  timeout value, so use it only when necessary as overuse
  will certainly slow down your test suite.
  """
  defmacro refute_reply(ref, status, payload \\ Macro.escape(%{}), timeout \\ Application.fetch_env!(:ex_unit, :refute_receive_timeout)) do
    quote do
      ref = unquote(ref)
      refute_receive %Phoenix.Socket.Reply{
                        ref: ^ref,
                        status: unquote(status),
                        payload: unquote(payload)}, unquote(timeout)
    end
  end

  @doc """
  Asserts the channel has broadcast a message within `timeout`.

  Before asserting anything was broadcast, we must first
  subscribe to the topic of the channel in the test process:

      @endpoint.subscribe("foo:ok")

  Now we can match on event and payload as patterns:

      assert_broadcast "some_event", %{"data" => _}

  In the assertion above, we don't particularly care about
  the data being sent, as long as something was sent.

  The timeout is in milliseconds and defaults to the `:assert_receive_timeout`
  set on the `:ex_unit` application (which defaults to 100ms).
  """
  defmacro assert_broadcast(event, payload, timeout \\ Application.fetch_env!(:ex_unit, :assert_receive_timeout)) do
    quote do
      assert_receive %Phoenix.Socket.Broadcast{event: unquote(event),
                                               payload: unquote(payload)}, unquote(timeout)
    end
  end

  @doc """
  Asserts the channel has not broadcast a message within `timeout`.

  Like `assert_broadcast`, the event and payload are patterns.

  The timeout is in milliseconds and defaults to the `:refute_receive_timeout`
  set on the `:ex_unit` application (which defaults to 100ms).
  Keep in mind this macro will block the test by the
  timeout value, so use it only when necessary as overuse
  will certainly slow down your test suite.
  """
  defmacro refute_broadcast(event, payload, timeout \\ Application.fetch_env!(:ex_unit, :refute_receive_timeout)) do
    quote do
      refute_receive %Phoenix.Socket.Broadcast{event: unquote(event),
                                               payload: unquote(payload)}, unquote(timeout)
    end
  end

  defp match_topic_to_channel!(socket, topic) do
    unless socket.handler do
      raise """
      no socket handler found to lookup channel for topic #{inspect topic}.
      Use connect/3 when calling subscribe_and_join/* (or subscribe_and_join!/*)
      without a channel, for example:

          {:ok, socket} = connect(UserSocket, %{}, %{})
          socket = subscribe_and_join!(socket, "foo:bar", %{})

      """
    end

    case socket.handler.__channel__(topic) do
      {channel, opts} when is_atom(channel) -> {channel, opts}
      _ -> raise "no channel found for topic #{inspect topic} in #{inspect socket.handler}"
    end
  end

  @doc false
  def __stringify__(%{__struct__: _} = struct),
    do: struct
  def __stringify__(%{} = params),
    do: Enum.into(params, %{}, &stringify_kv/1)
  def __stringify__(other),
    do: other

  defp stringify_kv({k, v}),
    do: {to_string(k), __stringify__(v)}
end
