defmodule Phoenix.Socket do
  @moduledoc ~S"""
  A socket implementation that multiplexes messages over channels.

  `Phoenix.Socket` is used as a module for establishing and maintaining
  the socket state via the `Phoenix.Socket` struct.

  Once connected to a socket, incoming and outgoing events are routed to
  channels. The incoming client data is routed to channels via transports.
  It is the responsibility of the socket to tie transports and channels
  together.

  By default, Phoenix supports both websockets and longpoll when invoking
  `Phoenix.Endpoint.socket/3` in your endpoint:

      socket "/socket", MyApp.Socket, websocket: true, longpoll: false

  The command above means incoming socket connections can be made via
  a WebSocket connection. Events are routed by topic to channels:

      channel "room:lobby", MyApp.LobbyChannel

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

      defmodule MyApp.UserSocket do
        use Phoenix.Socket

        channel "room:*", MyApp.RoomChannel

        def connect(params, socket, _connect_info) do
          {:ok, assign(socket, :user_id, params["user_id"])}
        end

        def id(socket), do: "users_socket:#{socket.assigns.user_id}"
      end

      # Disconnect all user's socket connections and their multiplexed channels
      MyApp.Endpoint.broadcast("users_socket:" <> user.id, "disconnect", %{})

  ## Socket fields

    * `:id` - The string id of the socket
    * `:assigns` - The map of socket assigns, default: `%{}`
    * `:channel` - The current channel module
    * `:channel_pid` - The channel pid
    * `:endpoint` - The endpoint module where this socket originated, for example: `MyApp.Endpoint`
    * `:handler` - The socket module where this socket originated, for example: `MyApp.UserSocket`
    * `:joined` - If the socket has effectively joined the channel
    * `:join_ref` - The ref sent by the client when joining
    * `:ref` - The latest ref sent by the client
    * `:pubsub_server` - The registered name of the socket's pubsub server
    * `:topic` - The string topic, for example `"room:123"`
    * `:transport` - An identifier for the transport, used for logging
    * `:transport_pid` - The pid of the socket's transport process
    * `:serializer` - The serializer for socket messages

  ## Logging

  Logging for socket connections is set via the `:log` option, for example:

      use Phoenix.Socket, log: :debug

  Defaults to the `:info` log level. Pass `false` to disable logging.

  ## Client-server communication

  The encoding of server data and the decoding of client data is done
  according to a serializer, defined in `Phoenix.Socket.Serializer`.
  By default, JSON encoding is used to broker messages to and from
  clients with `Phoenix.Socket.V2.JSONSerializer`.

  The serializer `encode!/1` and `fastlane!/1` functions must return
  a tuple in the format `{:text | :binary, iodata}`.

  The serializer `decode!` function must return a `Phoenix.Socket.Message`
  which is forwarded to channels except:

    * "heartbeat" events in the "phoenix" topic - should just emit an OK reply
    * "phx_join" on any topic - should join the topic
    * "phx_leave" on any topic - should leave the topic

  Each message also has a `ref` field which is used to track responses.

  The server may send messages or replies back. For messages, the
  ref uniquely identifies the message. For replies, the ref matches
  the original message. Both data-types also include a join_ref that
  uniquely identifes the currently joined channel.

  The `Phoenix.Socket` implementation may also sent special messages
  and replies:

    * "phx_error" - in case of errors, such as a channel process
      crashing, or when attempting to join an already joined channel

    * "phx_close" - the channel was gracefully closed

  Phoenix ships with a JavaScript implementation of both websocket
  and long polling that interacts with Phoenix.Socket and can be
  used as reference for those interested in implementing custom clients.

  ## Custom sockets and transports

  See the `Phoenix.Socket.Transport` documentation for more information on
  writing your own socket that does not leverage channels or for writing
  your own transports that interacts with other sockets.

  ## Garbage collection

  It's possible to force garbage collection in the transport process after
  processing large messages. For example, to trigger such from your channels,
  run:

      send(socket.transport_pid, :garbage_collect)

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

  To deny connection, return `:error`.

  See `Phoenix.Token` documentation for examples in
  performing token verification on connect.
  """
  @callback connect(params :: map, Socket.t) :: {:ok, Socket.t} | :error
  @callback connect(params :: map, Socket.t, connect_info :: map) :: {:ok, Socket.t} | :error

  @doc ~S"""
  Identifies the socket connection.

  Socket IDs are topics that allow you to identify all sockets for a given user:

      def id(socket), do: "users_socket:#{socket.assigns.user_id}"

  Would allow you to broadcast a "disconnect" event and terminate
  all active sockets and channels for a given user:

      MyApp.Endpoint.broadcast("users_socket:" <> user.id, "disconnect", %{})

  Returning `nil` makes this socket anonymous.
  """
  @callback id(Socket.t) :: String.t | nil

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
          id: nil,
          joined: boolean,
          ref: term,
          private: %{},
          pubsub_server: atom,
          serializer: atom,
          topic: String.t,
          transport: atom,
          transport_pid: pid,
        }

  defmacro __using__(opts) do
    quote do
      ## User API

      import Phoenix.Socket
      @behaviour Phoenix.Socket
      @before_compile Phoenix.Socket
      Module.register_attribute(__MODULE__, :phoenix_channels, accumulate: true)
      @phoenix_transports %{}
      @phoenix_log Keyword.get(unquote(opts), :log, :info)

      ## Callbacks

      @behaviour Phoenix.Socket.Transport

      @doc false
      def child_spec(opts) do
        Phoenix.Socket.__child_spec__(__MODULE__, opts)
      end

      @doc false
      def connect(map), do: Phoenix.Socket.__connect__(__MODULE__, map, @phoenix_log)

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
  Adds a key/value pair to socket assigns.

  ## Examples

      iex> socket.assigns[:token]
      nil
      iex> socket = assign(socket, :token, "bar")
      iex> socket.assigns[:token]
      "bar"

  """
  def assign(socket = %Socket{}, key, value) do
    put_in socket.assigns[key], value
  end

  @doc """
  Defines a channel matching the given topic and transports.

    * `topic_pattern` - The string pattern, for example "room:*", "users:*", "system"
    * `module` - The channel module handler, for example `MyApp.RoomChannel`
    * `opts` - The optional list of options, see below

  ## Options

    * `:assigns` - the map of socket assigns to merge into the socket on join

  ## Examples

      channel "topic1:*", MyChannel

  ## Topic Patterns

  The `channel` macro accepts topic patterns in two flavors. A splat argument
  can be provided as the last character to indicate a "topic:subtopic" match. If
  a plain string is provided, only that topic will match the channel handler.
  Most use-cases will use the "topic:*" pattern to allow more versatile topic
  scoping.

  See `Phoenix.Channel` for more information
  """
  defmacro channel(topic_pattern, module, opts \\ []) do
    # Tear the alias to simply store the root in the AST.
    # This will make Elixir unable to track the dependency between
    # endpoint <-> socket and avoid recompiling the endpoint
    # (alongside the whole project) whenever the socket changes.
    module = tear_alias(module)

    quote do
      @phoenix_channels {unquote(topic_pattern), unquote(module), unquote(opts)}
    end
  end

  defp tear_alias({:__aliases__, meta, [h|t]}) do
    alias = {:__aliases__, meta, [h]}
    quote do
      Module.concat([unquote(alias)|unquote(t)])
    end
  end
  defp tear_alias(other), do: other

  # TODO: Remove the transport/3 implementation on v1.5
  # but we should keep the warning for backwards compatibility.

  @doc false
  defmacro transport(name, module, config \\ []) do
    quote do
      @phoenix_transports Phoenix.Socket.__transport__(
        @phoenix_transports, unquote(name), unquote(module), unquote(config))
    end
  end

  @doc false
  def __transport__(transports, name, module, user_conf) do
    IO.warn """
    transport/3 in Phoenix.Socket is deprecated.

    Instead of defining transports in your socket.ex file:

        transport :websocket, Phoenix.Transport.Websocket,
          key1: value1, key2: value2, key3: value3

        transport :longpoll, Phoenix.Transport.LongPoll,
          key1: value1, key2: value2, key3: value3

    You should configure websocket/longpoll in your endpoint.ex:

        socket "/socket", MyApp.UserSocket,
          websocket: [key1: value1, key2: value2, key3: value3],
          longpoll: [key1: value1, key2: value2, key3: value3]

    Note the websocket/longpoll configuration given to socket/3
    will only apply after you remove all transport/3 calls from
    your socket definition. If you have explicitly upgraded to
    Cowboy 2, any transport defined with the transport/3 macro
    will be ignored.
    """

    defaults = module.default_config()

    conf =
      user_conf
      |> normalize_serializer_conf(name, module, defaults[:serializer] || [])
      |> merge_defaults(defaults)

    Map.update(transports, name, {module, conf}, fn {dup_module, _} ->
      raise ArgumentError,
        "duplicate transports (#{inspect dup_module} and #{inspect module}) defined for #{inspect name}"
    end)
  end
  defp merge_defaults(conf, defaults), do: Keyword.merge(defaults, conf)

  defp normalize_serializer_conf(conf, name, transport_mod, default) do
    update_in(conf[:serializer], fn
      nil ->
        precompile_serializers(default)

      Phoenix.Transports.LongPollSerializer = serializer ->
        warn_serializer_deprecation(name, transport_mod, serializer)
        precompile_serializers(default)

      Phoenix.Transports.WebSocketSerializer = serializer ->
        warn_serializer_deprecation(name, transport_mod, serializer)
        precompile_serializers(default)

      [_ | _] = serializer ->
        precompile_serializers(serializer)

      serializer when is_atom(serializer) ->
        warn_serializer_deprecation(name, transport_mod, serializer)
        precompile_serializers([{serializer, "~> 1.0.0"}])
    end)
  end

  defp warn_serializer_deprecation(name, transport_mod, serializer) do
    IO.warn """
    passing a serializer module to the transport macro is deprecated.
    Use a list with version requirements instead. For example:

        transport :#{name}, #{inspect transport_mod},
          serializer: [{#{inspect serializer}, "~> 1.0.0"}]

    """
  end

  defp precompile_serializers(serializers) do
    for {module, requirement} <- serializers do
      case Version.parse_requirement(requirement) do
        {:ok, requirement} -> {rewrite_serializer(module), requirement}
        :error -> Version.match?("1.0.0", requirement)
      end
    end
  end

  defp rewrite_serializer(Phoenix.Transports.V2.WebSocketSerializer), do: Phoenix.Socket.V2.JSONSerializer
  defp rewrite_serializer(Phoenix.Transports.V2.LongPollSerializer), do: Phoenix.Socket.V2.JSONSerializer
  defp rewrite_serializer(Phoenix.Transports.WebSocketSerializer), do: Phoenix.Socket.V1.JSONSerializer
  defp rewrite_serializer(Phoenix.Transports.LongPollSerializer), do: Phoenix.Socket.V1.JSONSerializer
  defp rewrite_serializer(module), do: module

  defmacro __before_compile__(env) do
    transports = Module.get_attribute(env.module, :phoenix_transports)
    channels   = Module.get_attribute(env.module, :phoenix_channels)

    channel_defs =
      for {topic_pattern, module, opts} <- channels do
        topic_pattern
        |> to_topic_match()
        |> defchannel(module, opts)
      end

    quote do
      def __transports__, do: unquote(Macro.escape(transports))
      unquote(channel_defs)
      def __channel__(_topic), do: nil
    end
  end

  defp to_topic_match(topic_pattern) do
    case String.split(topic_pattern, "*") do
      [prefix, ""] -> quote do: <<unquote(prefix) <> _rest>>
      [bare_topic] -> bare_topic
      _            -> raise ArgumentError, "channels using splat patterns must end with *"
    end
  end

  defp defchannel(topic_match, channel_module, opts) do
    quote do
      def __channel__(unquote(topic_match)), do: unquote({channel_module, Macro.escape(opts)})
    end
  end

  ## CALLBACKS IMPLEMENTATION

  def __child_spec__(handler, opts) do
    import Supervisor.Spec
    endpoint = Keyword.fetch!(opts, :endpoint)
    shutdown = Keyword.get(opts, :shutdown, 5_000)
    partitions = Keyword.get(opts, :partitions) || System.schedulers_online()

    worker_opts = [shutdown: shutdown, restart: :temporary]
    worker = worker(Phoenix.Channel.Server, [], worker_opts)
    args = {endpoint, handler, partitions, worker}
    supervisor(Phoenix.Socket.PoolSupervisor, [args], id: handler)
  end

  def __connect__(user_socket, map, log) do
    %{
      endpoint: endpoint,
      options: options,
      transport: transport,
      params: params,
      connect_info: connect_info
    } = map
    vsn = params["vsn"] || "1.0.0"
    meta = Map.merge(map, %{vsn: vsn, user_socket: user_socket, log: log})

    Phoenix.Endpoint.instrument(endpoint, :phoenix_socket_connect, meta, fn ->
      case negotiate_serializer(Keyword.fetch!(options, :serializer), vsn) do
        {:ok, serializer} ->
          user_socket
          |> user_connect(endpoint, transport, serializer, params, connect_info)
          |> log_connect_result(user_socket, log)

        :error -> :error
      end
    end)
  end

  defp log_connect_result(result, _user_socket, false = _level), do: result
  defp log_connect_result({:ok, _} = result, user_socket, level) do
    Logger.log(level, fn -> "Replied #{inspect(user_socket)} :ok" end)
    result
  end
  defp log_connect_result(:error = result, user_socket, level) do
    Logger.log(level, fn -> "Replied #{inspect(user_socket)} :error" end)
    result
  end

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

  def __info__({:graceful_exit, pid, %Phoenix.Socket.Message{} = message}, {state, socket}) do
    state =
      case state.channels_inverse do
        %{^pid => {topic, _join_ref}} ->
          {^pid, monitor_ref} = Map.fetch!(state.channels, topic)
          delete_channel(state, pid, topic, monitor_ref)

        %{} ->
          state
      end

    {:push, encode_reply(socket, message), {state, socket}}
  end

  def __info__(%Broadcast{event: "disconnect"}, state) do
    {:stop, {:shutdown, :disconnected}, state}
  end

  def __info__({:socket_push, opcode, payload}, state) do
    {:push, {opcode, payload}, state}
  end

  def __info__(:garbage_collect, state) do
    :erlang.garbage_collect(self())
    {:ok, state}
  end

  def __info__(_, state) do
    {:ok, state}
  end

  def __terminate__(_reason, {%{channels_inverse: channels_inverse}, _socket}) do
    Phoenix.Channel.Server.close(Map.keys(channels_inverse))
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
            Logger.error "The client's requested transport version \"#{vsn}\" " <>
                          "does not match server's version requirements of #{inspect serializers}"
            :error
        end

      :error ->
        Logger.error "Client sent invalid transport version \"#{vsn}\""
        :error
    end
  end

  defp user_connect(handler, endpoint, transport, serializer, params, connect_info) do
    # The information in the Phoenix.Socket goes to userland and channels.
    socket = %Socket{
      handler: handler,
      endpoint: endpoint,
      pubsub_server: endpoint.__pubsub_server__,
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
            Logger.error "#{inspect handler}.id/1 returned invalid identifier " <>
                           "#{inspect invalid}. Expected nil or a string."
            :error
        end

      :error ->
        :error

      invalid ->
        connect_arity = if function_exported?(handler, :connect, 3), do: "connect/3", else: "connect/2"
        Logger.error "#{inspect handler}. #{connect_arity} returned invalid value #{inspect invalid}. " <>
                     "Expected {:ok, socket} or :error"
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

  defp handle_in(nil, %{event: "phx_join", topic: topic, ref: ref} = message, state, socket) do
    case socket.handler.__channel__(topic) do
      {channel, opts} ->
        case Phoenix.Channel.Server.join(socket, channel, message, opts) do
          {:ok, reply, pid} ->
            reply = %Reply{join_ref: ref, ref: ref, topic: topic, status: :ok, payload: reply}
            state = put_channel(state, pid, topic, ref)
            {:reply, :ok, encode_reply(socket, reply), {state, socket}}

          {:error, reply} ->
            reply = %Reply{join_ref: ref, ref: ref, topic: topic, status: :error, payload: reply}
            {:reply, :error, encode_reply(socket, reply), {state, socket}}
        end

      _ ->
        {:reply, :error, encode_ignore(socket, message), {state, socket}}
    end
  end

  defp handle_in({pid, ref}, %{event: "phx_join", topic: topic} = message, state, socket) do
    Logger.debug fn ->
      "Duplicate channel join for topic \"#{topic}\" in #{inspect(socket.handler)}. " <>
        "Closing existing channel for new join."
    end

    :ok = Phoenix.Channel.Server.close([pid])
    handle_in(nil, message, delete_channel(state, pid, topic, ref), socket)
  end

  defp handle_in({pid, _ref}, message, state, socket) do
    send(pid, message)
    {:ok, {state, socket}}
  end

  defp handle_in(nil, message, state, socket) do
    {:reply, :error, encode_ignore(socket, message), {state, socket}}
  end

  defp put_channel(state, pid, topic, join_ref) do
    %{channels: channels, channels_inverse: channels_inverse} = state
    monitor_ref = Process.monitor(pid)

    %{
      state |
        channels: Map.put(channels, topic, {pid, monitor_ref}),
        channels_inverse: Map.put(channels_inverse, pid, {topic, join_ref})
    }
  end

  defp delete_channel(state, pid, topic, monitor_ref) do
    %{channels: channels, channels_inverse: channels_inverse} = state
    Process.demonitor(monitor_ref, [:flush])

    %{
      state |
        channels: Map.delete(channels, topic),
        channels_inverse: Map.delete(channels_inverse, pid)
    }
  end

  defp encode_on_exit(socket, topic, ref, _reason) do
    message = %Message{join_ref: ref, ref: ref, topic: topic, event: "phx_error", payload: %{}}
    encode_reply(socket, message)
  end

  defp encode_ignore(%{handler: handler} = socket, %{ref: ref, topic: topic}) do
    Logger.warn fn -> "Ignoring unmatched topic \"#{topic}\" in #{inspect(handler)}" end
    reply = %Reply{ref: ref, topic: topic, status: :error, payload: %{reason: "unmatched topic"}}
    encode_reply(socket, reply)
  end

  defp encode_reply(%{serializer: serializer}, message) do
    {:socket_push, opcode, payload} = serializer.encode!(message)
    {opcode, payload}
  end
end
