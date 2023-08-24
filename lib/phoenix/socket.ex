defmodule Phoenix.Socket do
  @moduledoc ~S"""
  A socket implementation that multiplexes messages over channels.

  `Phoenix.Socket` is used as a module for establishing a connection
  between client and server. Once the connection is established,
  the initial state is stored in the `Phoenix.Socket` struct.

  The same socket can be used to receive events from different transports.
  Phoenix supports `websocket` and `longpoll` options when invoking
  `Phoenix.Endpoint.socket/3` in your endpoint. `websocket` is set by default
  and `longpoll` can also be configured explicitly.

      socket "/socket", MyAppWeb.Socket, websocket: true, longpoll: false

  The command above means incoming socket connections can be made via
  a WebSocket connection. Incoming and outgoing events are routed to
  channels by topic:

      channel "room:lobby", MyAppWeb.LobbyChannel

  See `Phoenix.Channel` for more information on channels.

  ## Socket Behaviour

  Socket handlers are mounted in Endpoints and must define two callbacks:

    * `connect/3` - receives the socket params, connection info if any, and
      authenticates the connection. Must return a `Phoenix.Socket` struct,
      often with custom assigns

    * `id/1` - receives the socket returned by `connect/3` and returns the
      id of this connection as a string. The `id` is used to identify socket
      connections, often to a particular user, allowing us to force disconnections.
      For sockets requiring no authentication, `nil` can be returned

  ## Examples

      defmodule MyAppWeb.UserSocket do
        use Phoenix.Socket

        channel "room:*", MyAppWeb.RoomChannel

        def connect(params, socket, _connect_info) do
          {:ok, assign(socket, :user_id, params["user_id"])}
        end

        def id(socket), do: "users_socket:#{socket.assigns.user_id}"
      end

      # Disconnect all user's socket connections and their multiplexed channels
      MyAppWeb.Endpoint.broadcast("users_socket:" <> user.id, "disconnect", %{})

  ## Socket fields

    * `:id` - The string id of the socket
    * `:assigns` - The map of socket assigns, default: `%{}`
    * `:channel` - The current channel module
    * `:channel_pid` - The channel pid
    * `:endpoint` - The endpoint module where this socket originated, for example: `MyAppWeb.Endpoint`
    * `:handler` - The socket module where this socket originated, for example: `MyAppWeb.UserSocket`
    * `:joined` - If the socket has effectively joined the channel
    * `:join_ref` - The ref sent by the client when joining
    * `:ref` - The latest ref sent by the client
    * `:pubsub_server` - The registered name of the socket's pubsub server
    * `:topic` - The string topic, for example `"room:123"`
    * `:transport` - An identifier for the transport, used for logging
    * `:transport_pid` - The pid of the socket's transport process
    * `:serializer` - The serializer for socket messages

  ## Using options

  On `use Phoenix.Socket`, the following options are accepted:

    * `:log` - the default level to log socket actions. Defaults
      to `:info`. May be set to `false` to disable it

    * `:partitions` - each channel is spawned under a supervisor.
      This option controls how many supervisors will be spawned
      to handle channels. Defaults to the number of cores.

  ## Garbage collection

  It's possible to force garbage collection in the transport process after
  processing large messages. For example, to trigger such from your channels,
  run:

      send(socket.transport_pid, :garbage_collect)

  Alternatively, you can configure your endpoint socket to trigger more
  fullsweep garbage collections more frequently, by setting the `:fullsweep_after`
  option for websockets. See `Phoenix.Endpoint.socket/3` for more info.

  ## Client-server communication

  The encoding of server data and the decoding of client data is done
  according to a serializer, defined in `Phoenix.Socket.Serializer`.
  By default, JSON encoding is used to broker messages to and from clients.

  The serializer `decode!` function must return a `Phoenix.Socket.Message`
  which is forwarded to channels except:

    * `"heartbeat"` events in the "phoenix" topic - should just emit an OK reply
    * `"phx_join"` on any topic - should join the topic
    * `"phx_leave"` on any topic - should leave the topic

  Each message also has a `ref` field which is used to track responses.

  The server may send messages or replies back. For messages, the
  ref uniquely identifies the message. For replies, the ref matches
  the original message. Both data-types also include a join_ref that
  uniquely identifies the currently joined channel.

  The `Phoenix.Socket` implementation may also send special messages
  and replies:

    * `"phx_error"` - in case of errors, such as a channel process
      crashing, or when attempting to join an already joined channel

    * `"phx_close"` - the channel was gracefully closed

  Phoenix ships with a JavaScript implementation of both websocket
  and long polling that interacts with Phoenix.Socket and can be
  used as reference for those interested in implementing custom clients.

  ## Custom sockets and transports

  See the `Phoenix.Socket.Transport` documentation for more information on
  writing your own socket that does not leverage channels or for writing
  your own transports that interacts with other sockets.

  ## Custom channels

  You can list any module as a channel as long as it implements
  a `child_spec/1` function. The `child_spec/1` function receives
  the caller as argument and it must return a child spec that
  initializes a process.

  Once the process is initialized, it will receive the following
  message:

      {Phoenix.Channel, auth_payload, from, socket}

  A custom channel implementation MUST invoke
  `GenServer.reply(from, {:ok | :error, reply_payload})` during its
  initialization with a custom `reply_payload` that will be sent as
  a reply to the client. Failing to do so will block the socket forever.

  A custom channel receives `Phoenix.Socket.Message` structs as regular
  messages from the transport. Replies to those messages and custom
  messages can be sent to the socket at any moment by building an
  appropriate `Phoenix.Socket.Reply` and `Phoenix.Socket.Message`
  structs, encoding them with the serializer and dispatching the
  serialized result to the transport.

  For example, to handle "phx_leave" messages, which is recommended
  to be handled by all channel implementations, one may do:

      def handle_info(
            %Message{topic: topic, event: "phx_leave"} = message,
            %{topic: topic, serializer: serializer, transport_pid: transport_pid} = socket
          ) do
        send transport_pid, serializer.encode!(build_leave_reply(message))
        {:stop, {:shutdown, :left}, socket}
      end

  A special message delivered to all channels is a Broadcast with
  event "phx_drain", which is sent when draining the socket during
  application shutdown. Typically it is handled by sending a drain
  message to the transport, causing it to shutdown:

      def handle_info(
            %Broadcast{event: "phx_drain"},
            %{transport_pid: transport_pid} = socket
          ) do
        send(transport_pid, :socket_drain)
        {:stop, {:shutdown, :draining}, socket}
      end

  We also recommend all channels to monitor the `transport_pid`
  on `init` and exit if the transport exits. We also advise to rewrite
  `:normal` exit reasons (usually due to the socket being closed)
  to the `{:shutdown, :closed}` to guarantee links are broken on
  the channel exit (as a `:normal` exit does not break links):

      def handle_info({:DOWN, _, _, transport_pid, reason}, %{transport_pid: transport_pid} = socket) do
        reason = if reason == :normal, do: {:shutdown, :closed}, else: reason
        {:stop, reason, socket}
      end

  Any process exit is treated as an error by the socket layer unless
  a `{:socket_close, pid, reason}` message is sent to the socket before
  shutdown.

  Custom channel implementations cannot be tested with `Phoenix.ChannelTest`.
  """

  require Logger
  require Phoenix.Endpoint
  alias Phoenix.Socket
  alias Phoenix.Socket.{Broadcast, Message, Reply}

  @doc """
  Receives the socket params and authenticates the connection.

  ## Socket params and assigns

  Socket params are passed from the client and can
  be used to verify and authenticate a user. After
  verification, you can put default assigns into
  the socket that will be set for all channels, ie

      {:ok, assign(socket, :user_id, verified_user_id)}

  To deny connection, return `:error` or `{:error, term}`. To control the
  response the client receives in that case, [define an error handler in the
  websocket
  configuration](https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#socket/3-websocket-configuration).

  See `Phoenix.Token` documentation for examples in
  performing token verification on connect.
  """
  @callback connect(params :: map, Socket.t(), connect_info :: map) ::
              {:ok, Socket.t()} | {:error, term} | :error

  @doc """
  Shortcut version of `connect/3` which does not receive `connect_info`.

  Provided for backwards compatibility.
  """
  @callback connect(params :: map, Socket.t()) :: {:ok, Socket.t()} | {:error, term} | :error

  @doc ~S"""
  Identifies the socket connection.

  Socket IDs are topics that allow you to identify all sockets for a given user:

      def id(socket), do: "users_socket:#{socket.assigns.user_id}"

  Would allow you to broadcast a `"disconnect"` event and terminate
  all active sockets and channels for a given user:

      MyAppWeb.Endpoint.broadcast("users_socket:" <> user.id, "disconnect", %{})

  Returning `nil` makes this socket anonymous.
  """
  @callback id(Socket.t()) :: String.t() | nil

  @optional_callbacks connect: 2, connect: 3

  defmodule InvalidMessageError do
    @moduledoc """
    Raised when the socket message is invalid.
    """
    defexception [:message]
  end

  defstruct assigns: %{},
            channel: nil,
            channel_pid: nil,
            endpoint: nil,
            handler: nil,
            id: nil,
            joined: false,
            join_ref: nil,
            private: %{},
            pubsub_server: nil,
            ref: nil,
            serializer: nil,
            topic: nil,
            transport: nil,
            transport_pid: nil

  @type t :: %Socket{
          assigns: map,
          channel: atom,
          channel_pid: pid,
          endpoint: atom,
          handler: atom,
          id: String.t() | nil,
          joined: boolean,
          ref: term,
          private: map,
          pubsub_server: atom,
          serializer: atom,
          topic: String.t(),
          transport: atom,
          transport_pid: pid
        }

  defmacro __using__(opts) do
    quote do
      ## User API

      import Phoenix.Socket
      @behaviour Phoenix.Socket
      @before_compile Phoenix.Socket
      Module.register_attribute(__MODULE__, :phoenix_channels, accumulate: true)
      @phoenix_socket_options unquote(opts)

      ## Callbacks

      @behaviour Phoenix.Socket.Transport

      @doc false
      def child_spec(opts) do
        Phoenix.Socket.__child_spec__(__MODULE__, opts, @phoenix_socket_options)
      end

      @doc false
      def drainer_spec(opts) do
        Phoenix.Socket.__drainer_spec__(__MODULE__, opts, @phoenix_socket_options)
      end

      @doc false
      def connect(map), do: Phoenix.Socket.__connect__(__MODULE__, map, @phoenix_socket_options)

      @doc false
      def init(state), do: Phoenix.Socket.__init__(state)

      @doc false
      def handle_in(message, state), do: Phoenix.Socket.__in__(message, state)

      @doc false
      def handle_info(message, state), do: Phoenix.Socket.__info__(message, state)

      @doc false
      def terminate(reason, state), do: Phoenix.Socket.__terminate__(reason, state)
    end
  end

  ## USER API

  @doc """
  Adds key-value pairs to socket assigns.

  A single key-value pair may be passed, a keyword list or map
  of assigns may be provided to be merged into existing socket
  assigns.

  ## Examples

      iex> assign(socket, :name, "Elixir")
      iex> assign(socket, name: "Elixir", logo: "💧")
  """
  def assign(%Socket{} = socket, key, value) do
    assign(socket, [{key, value}])
  end

  def assign(%Socket{} = socket, attrs)
      when is_map(attrs) or is_list(attrs) do
    %{socket | assigns: Map.merge(socket.assigns, Map.new(attrs))}
  end

  @doc """
  Defines a channel matching the given topic and transports.

    * `topic_pattern` - The string pattern, for example `"room:*"`, `"users:*"`,
      or `"system"`
    * `module` - The channel module handler, for example `MyAppWeb.RoomChannel`
    * `opts` - The optional list of options, see below

  ## Options

    * `:assigns` - the map of socket assigns to merge into the socket on join

  ## Examples

      channel "topic1:*", MyChannel

  ## Topic Patterns

  The `channel` macro accepts topic patterns in two flavors. A splat (the `*`
  character) argument can be provided as the last character to indicate a
  `"topic:subtopic"` match. If a plain string is provided, only that topic will
  match the channel handler. Most use-cases will use the `"topic:*"` pattern to
  allow more versatile topic scoping.

  See `Phoenix.Channel` for more information
  """
  defmacro channel(topic_pattern, module, opts \\ []) do
    module = expand_alias(module, __CALLER__)

    opts =
      if Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, __CALLER__))
      else
        opts
      end

    quote do
      @phoenix_channels {unquote(topic_pattern), unquote(module), unquote(opts)}
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:channel, 3}})

  defp expand_alias(other, _env), do: other

  @doc false
  @deprecated "transport/3 in Phoenix.Socket is deprecated and has no effect"
  defmacro transport(_name, _module, _config \\ []) do
    :ok
  end

  defmacro __before_compile__(env) do
    channels =
      env.module
      |> Module.get_attribute(:phoenix_channels, [])
      |> Enum.reverse()

    channel_defs =
      for {topic_pattern, module, opts} <- channels do
        topic_pattern
        |> to_topic_match()
        |> defchannel(module, opts)
      end

    quote do
      unquote(channel_defs)
      def __channel__(_topic), do: nil
    end
  end

  defp to_topic_match(topic_pattern) do
    case String.split(topic_pattern, "*") do
      [prefix, ""] -> quote do: <<unquote(prefix) <> _rest>>
      [bare_topic] -> bare_topic
      _ -> raise ArgumentError, "channels using splat patterns must end with *"
    end
  end

  defp defchannel(topic_match, channel_module, opts) do
    quote do
      def __channel__(unquote(topic_match)), do: unquote({channel_module, Macro.escape(opts)})
    end
  end

  ## CALLBACKS IMPLEMENTATION

  def __child_spec__(handler, opts, socket_options) do
    endpoint = Keyword.fetch!(opts, :endpoint)
    opts = Keyword.merge(socket_options, opts)
    partitions = Keyword.get(opts, :partitions, System.schedulers_online())
    args = {endpoint, handler, partitions}
    Supervisor.child_spec({Phoenix.Socket.PoolSupervisor, args}, id: handler)
  end

  def __drainer_spec__(handler, opts, socket_options) do
    endpoint = Keyword.fetch!(opts, :endpoint)
    opts = Keyword.merge(socket_options, opts)

    if drainer = Keyword.get(opts, :drainer, []) do
      drainer =
        case drainer do
          {module, function, arguments} ->
            apply(module, function, arguments)
          _ ->
            drainer
        end
        {Phoenix.Socket.PoolDrainer, {endpoint, handler, drainer}}
    else
      :ignore
    end
  end

  def __connect__(user_socket, map, socket_options) do
    %{
      endpoint: endpoint,
      options: options,
      transport: transport,
      params: params,
      connect_info: connect_info
    } = map

    vsn = params["vsn"] || "1.0.0"

    options = Keyword.merge(socket_options, options)
    start = System.monotonic_time()

    case negotiate_serializer(Keyword.fetch!(options, :serializer), vsn) do
      {:ok, serializer} ->
        result = user_connect(user_socket, endpoint, transport, serializer, params, connect_info)

        metadata = %{
          endpoint: endpoint,
          transport: transport,
          params: params,
          connect_info: connect_info,
          vsn: vsn,
          user_socket: user_socket,
          log: Keyword.get(options, :log, :info),
          result: result(result),
          serializer: serializer
        }

        duration = System.monotonic_time() - start
        :telemetry.execute([:phoenix, :socket_connected], %{duration: duration}, metadata)
        result

      :error ->
        :error
    end
  end

  defp result({:ok, _}), do: :ok
  defp result(:error), do: :error
  defp result({:error, _}), do: :error

  def __init__({state, %{id: id, endpoint: endpoint} = socket}) do
    _ = id && endpoint.subscribe(id, link: true)
    {:ok, {state, %{socket | transport_pid: self()}}}
  end

  def __in__({payload, opts}, {state, socket}) do
    %{topic: topic} = message = socket.serializer.decode!(payload, opts)
    handle_in(Map.get(state.channels, topic), message, state, socket)
  end

  def __info__({:DOWN, ref, _, pid, reason}, {state, socket}) do
    case state.channels_inverse do
      %{^pid => {topic, join_ref}} ->
        state = delete_channel(state, pid, topic, ref)
        {:push, encode_on_exit(socket, topic, join_ref, reason), {state, socket}}

      %{} ->
        {:ok, {state, socket}}
    end
  end

  def __info__(%Broadcast{event: "disconnect"}, state) do
    {:stop, {:shutdown, :disconnected}, state}
  end

  def __info__(:socket_drain, state) do
    # downstream websock_adapter's will close with 1012 Service Restart
    {:stop, {:shutdown, :restart}, state}
  end

  def __info__({:socket_push, opcode, payload}, state) do
    {:push, {opcode, payload}, state}
  end

  def __info__({:socket_close, pid, _reason}, state) do
    socket_close(pid, state)
  end

  def __info__(:garbage_collect, state) do
    :erlang.garbage_collect(self())
    {:ok, state}
  end

  def __info__(_, state) do
    {:ok, state}
  end

  def __terminate__(_reason, _state_socket) do
    :ok
  end

  defp negotiate_serializer(serializers, vsn) when is_list(serializers) do
    case Version.parse(vsn) do
      {:ok, vsn} ->
        serializers
        |> Enum.find(:error, fn {_serializer, vsn_req} -> Version.match?(vsn, vsn_req) end)
        |> case do
          {serializer, _vsn_req} ->
            {:ok, serializer}

          :error ->
            Logger.warning(
              "The client's requested transport version \"#{vsn}\" " <>
                "does not match server's version requirements of #{inspect(serializers)}"
            )

            :error
        end

      :error ->
        Logger.warning("Client sent invalid transport version \"#{vsn}\"")
        :error
    end
  end

  defp user_connect(handler, endpoint, transport, serializer, params, connect_info) do
    # The information in the Phoenix.Socket goes to userland and channels.
    socket = %Socket{
      handler: handler,
      endpoint: endpoint,
      pubsub_server: endpoint.config(:pubsub_server),
      serializer: serializer,
      transport: transport
    }

    # The information in the state is kept only inside the socket process.
    state = %{
      channels: %{},
      channels_inverse: %{}
    }

    connect_result =
      if function_exported?(handler, :connect, 3) do
        handler.connect(params, socket, connect_info)
      else
        handler.connect(params, socket)
      end

    case connect_result do
      {:ok, %Socket{} = socket} ->
        case handler.id(socket) do
          nil ->
            {:ok, {state, socket}}

          id when is_binary(id) ->
            {:ok, {state, %{socket | id: id}}}

          invalid ->
            Logger.warning(
              "#{inspect(handler)}.id/1 returned invalid identifier " <>
                "#{inspect(invalid)}. Expected nil or a string."
            )

            :error
        end

      :error ->
        :error

      {:error, _reason} = err ->
        err

      invalid ->
        connect_arity =
          if function_exported?(handler, :connect, 3), do: "connect/3", else: "connect/2"

        Logger.error(
          "#{inspect(handler)}. #{connect_arity} returned invalid value #{inspect(invalid)}. " <>
            "Expected {:ok, socket}, {:error, reason} or :error"
        )

        :error
    end
  end

  defp handle_in(_, %{ref: ref, topic: "phoenix", event: "heartbeat"}, state, socket) do
    reply = %Reply{
      ref: ref,
      topic: "phoenix",
      status: :ok,
      payload: %{}
    }

    {:reply, :ok, encode_reply(socket, reply), {state, socket}}
  end

  defp handle_in(
         nil,
         %{event: "phx_join", topic: topic, ref: ref, join_ref: join_ref} = message,
         state,
         socket
       ) do
    case socket.handler.__channel__(topic) do
      {channel, opts} ->
        case Phoenix.Channel.Server.join(socket, channel, message, opts) do
          {:ok, reply, pid} ->
            reply = %Reply{
              join_ref: join_ref,
              ref: ref,
              topic: topic,
              status: :ok,
              payload: reply
            }

            state = put_channel(state, pid, topic, join_ref)
            {:reply, :ok, encode_reply(socket, reply), {state, socket}}

          {:error, reply} ->
            reply = %Reply{
              join_ref: join_ref,
              ref: ref,
              topic: topic,
              status: :error,
              payload: reply
            }

            {:reply, :error, encode_reply(socket, reply), {state, socket}}
        end

      _ ->
        Logger.warning("Ignoring unmatched topic \"#{topic}\" in #{inspect(socket.handler)}")
        {:reply, :error, encode_ignore(socket, message), {state, socket}}
    end
  end

  defp handle_in({pid, _ref, status}, %{event: "phx_join", topic: topic} = message, state, socket) do
    receive do
      {:socket_close, ^pid, _reason} -> :ok
    after
      0 ->
        if status != :leaving do
          Logger.debug(fn ->
            "Duplicate channel join for topic \"#{topic}\" in #{inspect(socket.handler)}. " <>
              "Closing existing channel for new join."
          end)
        end
    end

    :ok = shutdown_duplicate_channel(pid)
    {:push, {opcode, payload}, {new_state, new_socket}} = socket_close(pid, {state, socket})
    send(self(), {:socket_push, opcode, payload})
    handle_in(nil, message, new_state, new_socket)
  end

  defp handle_in({pid, _ref, _status}, %{event: "phx_leave"} = msg, state, socket) do
    %{topic: topic, join_ref: join_ref} = msg

    case state.channels_inverse do
      # we need to match on nil to handle v1 protocol
      %{^pid => {^topic, existing_join_ref}} when existing_join_ref in [join_ref, nil] ->
        send(pid, msg)
        {:ok, {update_channel_status(state, pid, topic, :leaving), socket}}

      # the client has raced a server close. No need to reply since we already sent close
      %{^pid => {^topic, _old_join_ref}} ->
        {:ok, {state, socket}}
    end
  end

  defp handle_in({pid, _ref, _status}, message, state, socket) do
    send(pid, message)
    {:ok, {state, socket}}
  end

  defp handle_in(
         nil,
         %{event: "phx_leave", ref: ref, topic: topic, join_ref: join_ref},
         state,
         socket
       ) do
    reply = %Reply{
      ref: ref,
      join_ref: join_ref,
      topic: topic,
      status: :ok,
      payload: %{}
    }

    {:reply, :ok, encode_reply(socket, reply), {state, socket}}
  end

  defp handle_in(nil, message, state, socket) do
    # This clause can happen if the server drops the channel
    # and the client sends a message meanwhile
    {:reply, :error, encode_ignore(socket, message), {state, socket}}
  end

  defp put_channel(state, pid, topic, join_ref) do
    %{channels: channels, channels_inverse: channels_inverse} = state
    monitor_ref = Process.monitor(pid)

    %{
      state
      | channels: Map.put(channels, topic, {pid, monitor_ref, :joined}),
        channels_inverse: Map.put(channels_inverse, pid, {topic, join_ref})
    }
  end

  defp delete_channel(state, pid, topic, monitor_ref) do
    %{channels: channels, channels_inverse: channels_inverse} = state
    Process.demonitor(monitor_ref, [:flush])

    %{
      state
      | channels: Map.delete(channels, topic),
        channels_inverse: Map.delete(channels_inverse, pid)
    }
  end

  defp encode_on_exit(socket, topic, ref, _reason) do
    message = %Message{join_ref: ref, ref: ref, topic: topic, event: "phx_error", payload: %{}}
    encode_reply(socket, message)
  end

  defp encode_ignore(socket, %{ref: ref, topic: topic}) do
    reply = %Reply{ref: ref, topic: topic, status: :error, payload: %{reason: "unmatched topic"}}
    encode_reply(socket, reply)
  end

  defp encode_reply(%{serializer: serializer}, message) do
    {:socket_push, opcode, payload} = serializer.encode!(message)
    {opcode, payload}
  end

  defp encode_close(socket, topic, join_ref) do
    message = %Message{
      join_ref: join_ref,
      ref: join_ref,
      topic: topic,
      event: "phx_close",
      payload: %{}
    }

    encode_reply(socket, message)
  end

  defp shutdown_duplicate_channel(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, {:shutdown, :duplicate_join})

    receive do
      {:DOWN, ^ref, _, _, _} -> :ok
    after
      5_000 ->
        Process.exit(pid, :kill)
        receive do: ({:DOWN, ^ref, _, _, _} -> :ok)
    end
  end

  defp socket_close(pid, {state, socket}) do
    case state.channels_inverse do
      %{^pid => {topic, join_ref}} ->
        {^pid, monitor_ref, _status} = Map.fetch!(state.channels, topic)
        state = delete_channel(state, pid, topic, monitor_ref)
        {:push, encode_close(socket, topic, join_ref), {state, socket}}

      %{} ->
        {:ok, {state, socket}}
    end
  end

  defp update_channel_status(state, pid, topic, status) do
    new_channels = Map.update!(state.channels, topic, fn {^pid, ref, _} -> {pid, ref, status} end)
    %{state | channels: new_channels}
  end
end
