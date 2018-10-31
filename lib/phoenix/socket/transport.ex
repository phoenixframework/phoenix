defmodule Phoenix.Socket.Transport do
  @moduledoc """
  Outlines the Socket <-> Transport communication.

  This module specifies a behaviour that all sockets must implement.
  `Phoenix.Socket` is just one possible implementation of a socket
  that multiplexes events over multiple channels. Developers can
  implement their own sockets as long as they implement the behaviour
  outlined here.

  Developers interested in implementing custom transports must invoke
  the socket API defined in this module. This module also provides
  many conveniences to make it easier to build custom transports.

  ## Workflow

  Whenever your endpoint starts, it will automatically invoke the
  `child_spec/1` on each listed socket and start that specification
  under the endpoint supervisor. For this reason, custom transports
  that are manually started in the supervision tree must be listed
  after the endpoint.

  Whenever the transport receives a connection, it should invoke the
  `c:connect/1` callback with a map of metadata. Different sockets may
  require different metadatas.

  If the connection is accepted, the transport can move the connection
  to another process, if so desires, or keep using the same process. The
  process responsible for managing the socket should then call `c:init/1`.

  For each message received from the client, the transport must call
  `c:handle_in/2` on the socket. For each informational message the
  transport receives, it should call `c:handle_info/2` on the socket.

  On termination, `c:terminate/2` must be called. A special atom with
  reason `:closed` can be used to specify that the client terminated
  the connection.

  ## Example

  Here is a simple pong socket implementation:

      defmodule PingSocket do
        @behaviour Phoenix.Socket.Transport

        def child_spec(opts) do
          # We won't spawn any process, so let's return a dummy task
          %{id: Task, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
        end

        def connect(map) do
          # Callback to retrieve relevant data from the connection.
          # The map contains options, params, transport and endpoint keys.
          {:ok, state}
        end

        def init(state) do
          # Now we are effectively inside the process that maintains the socket.
          {:ok, state}
        end

        def handle_in({"ping", _opts}, state) do
          {:reply, :ok, {:text, "pong"}, state}
        end

        def handle_info(_, state) do
          {:ok, state}
        end

        def terminate(_reason, _state) do
          :ok
        end
      end

  It can be mounted in your endpoint like any other socket:

      socket "/socket", PingSocket, websocket: true, longpoll: true

  You can now interact with the socket under `/socket/websocket`
  and `/socket/longpoll`.

  ## Security

  This module also provides functions to enable a secure environment
  on transports that, at some point, have access to a `Plug.Conn`.

  The functionality provided by this module helps in performing "origin"
  header checks and ensuring only SSL connections are allowed.
  """

  @type state :: term()

  @doc """
  Returns a child specification for socket management.

  This is invoked only once per socket regardless of
  the number of transports and should be responsible
  for setting up any process structure used exclusively
  by the socket regardless of transports.

  Each socket connection is started by the transport
  and the process that controls the socket likely
  belongs to the transport. However, some sockets spawn
  new processes, such as `Phoenix.Socket` which spawns
  channels, and this gives the ability to start a
  supervision tree associated to the socket.

  It receives the socket options from the endpoint,
  for example:

      socket "/my_app", MyApp.Socket, shutdown: 5000

  means `child_spec([shutdown: 5000])` will be invoked.
  """
  @callback child_spec(keyword) :: :supervisor.child_spec

  @doc """
  Connects to the socket.

  The transport passes a map of metadata and the socket
  returns `{:ok, state}` or `:error`. The state must be
  stored by the transport and returned in all future
  operations.

  This function is used for authorization purposes and it
  may be invoked outside of the process that effectively
  runs the socket.

  In the default `Phoenix.Socket` implementation, the
  metadata expects the following keys:

    * `:endpoint` - the application endpoint
    * `:transport` - the transport name
    * `:params` - the connection parameters
    * `:options` - a keyword list of transport options, often
      given by developers when configuring the transport.
      It must include a `:serializer` field with the list of
      serializers and their requirements

  """
  @callback connect(transport_info :: map) :: {:ok, state} | :error

  @doc """
  Initializes the socket state.

  This must be executed from the process that will effectively
  operate the socket.
  """
  @callback init(state) :: {:ok, state}

  @doc """
  Handles incoming socket messages.

  The message is represented as `{payload, options}`. It must
  return one of:

    * `{:ok, state}` - continues the socket with no reply
    * `{:reply, status, reply, state}` - continues the socket with reply
    * `{:stop, reason, state}` - stops the socket

  The `reply` is a tuple contain an `opcode` atom and a message that can
  be any term. The built-in websocket transport supports both `:text` and
  `:binary` opcode and the message must be always iodata. Long polling only
  supports text opcode.
  """
  @callback handle_in({message :: term, opts :: keyword}, state) ::
              {:ok, state}
              | {:reply, :ok | :error, {opcode :: atom, message :: term}, state}
              | {:stop, reason :: term, state}

  @doc """
  Handles info messages.

  The message is a term. It must return one of:

    * `{:ok, state}` - continues the socket with no reply
    * `{:push, reply, state}` - continues the socket with reply
    * `{:stop, reason, state}` - stops the socket

  The `reply` is a tuple contain an `opcode` atom and a message that can
  be any term. The built-in websocket transport supports both `:text` and
  `:binary` opcode and the message must be always iodata. Long polling only
  supports text opcode.
  """
  @callback handle_info(message :: term, state) ::
              {:ok, state}
              | {:push, {opcode :: atom, message :: term}, state}
              | {:stop, reason :: term, state}

  @doc """
  Invoked on termination.

  If `reason` is `:closed`, it means the client closed the socket.
  """
  @callback terminate(reason :: term, state) :: :ok

  require Logger
  alias Phoenix.Socket.{Reply, Message}

  @doc false
  def protocol_version do
    IO.warn "Phoenix.Socket.Transport.protocol_version/0 is deprecated"
    "2.0.0"
  end

  @doc false
  def connect(endpoint, handler, _transport_name, transport, serializers, params, _pid \\ self()) do
    IO.warn "Phoenix.Socket.Transport.connect/7 is deprecated"

    handler.connect(%{
      endpoint: endpoint,
      transport: transport,
      options: [serializer: serializers],
      params: params
    })
  end

  @doc false
  def dispatch(msg, channels, socket)

  def dispatch(%{ref: ref, topic: "phoenix", event: "heartbeat"}, _channels, socket) do
    IO.warn "Phoenix.Socket.Transport.dispatch/3 is deprecated"
    {:reply, %Reply{join_ref: socket.join_ref, ref: ref, topic: "phoenix", status: :ok, payload: %{}}}
  end

  def dispatch(%Message{} = msg, channels, socket) do
    IO.warn "Phoenix.Socket.Transport.dispatch/3 is deprecated"
    channels
    |> Map.get(msg.topic)
    |> do_dispatch(msg, socket)
  end

  defp do_dispatch(nil, %{event: "phx_join", topic: topic, ref: ref} = msg, socket) do
    case socket.handler.__channel__(topic) do
      {channel, opts} ->
        case Phoenix.Channel.Server.join(socket, channel, msg, opts) do
          {:ok, reply, pid} ->
            {:joined, pid, %Reply{join_ref: ref, ref: ref, topic: topic, status: :ok, payload: reply}}

          {:error, reply} ->
            {:error, reply, %Reply{join_ref: ref, ref: ref, topic: topic, status: :error, payload: reply}}
        end

      nil ->
        reply_ignore(msg, socket)
    end
  end

  defp do_dispatch({pid, _ref}, %{event: "phx_join"} = msg, socket) when is_pid(pid) do
    Logger.debug "Duplicate channel join for topic \"#{msg.topic}\" in #{inspect(socket.handler)}. " <>
                 "Closing existing channel for new join."
    :ok = Phoenix.Channel.Server.close([pid])
    do_dispatch(nil, msg, socket)
  end

  defp do_dispatch(nil, msg, socket) do
    reply_ignore(msg, socket)
  end

  defp do_dispatch({channel_pid, _ref}, msg, _socket) do
    send(channel_pid, msg)
    :noreply
  end

  defp reply_ignore(msg, socket) do
    Logger.warn fn -> "Ignoring unmatched topic \"#{msg.topic}\" in #{inspect(socket.handler)}" end
    {:error, :unmatched_topic, %Reply{join_ref: socket.join_ref, ref: msg.ref, topic: msg.topic, status: :error,
                                      payload: %{reason: "unmatched topic"}}}
  end

  @doc false
  def on_exit_message(topic, join_ref, _reason) do
    IO.warn "Phoenix.Socket.Transport.on_exit_mesage/3 is deprecated"
    %Message{join_ref: join_ref, ref: join_ref, topic: topic, event: "phx_error", payload: %{}}
  end

  @doc false
  def on_exit_message(topic, reason) do
    IO.warn "Phoenix.Transport.on_exit_message/2 is deprecated"
    on_exit_message(topic, nil, reason)
  end

  @doc """
  Runs the code reloader if enabled.
  """
  def code_reload(conn, endpoint, opts) do
    reload? = Keyword.get(opts, :code_reloader, endpoint.config(:code_reloader))
    reload? && Phoenix.CodeReloader.reload!(endpoint)
    conn
  end

  @doc """
  Forces SSL in the socket connection.

  Uses the endpoint configuration to decide so. It is a
  noop if the connection has been halted.
  """
  def force_ssl(%{halted: true} = conn, _socket, _endpoint, _opts) do
    conn
  end

  def force_ssl(conn, socket, endpoint, opts) do
    if force_ssl = force_ssl_config(socket, endpoint, opts) do
      Plug.SSL.call(conn, force_ssl)
    else
      conn
    end
  end

  defp force_ssl_config(socket, endpoint, opts) do
    Phoenix.Config.cache(endpoint, {:force_ssl, socket}, fn _ ->
      opts =
        if force_ssl = Keyword.get(opts, :force_ssl, endpoint.config(:force_ssl)) do
          force_ssl
          |> Keyword.put_new(:host, {endpoint, :host, []})
          |> Plug.SSL.init()
        end
      {:cache, opts}
    end)
  end

  @doc """
  Logs the transport request.

  Available for transports that generate a connection.
  """
  def transport_log(conn, level) do
    if level do
      Plug.Logger.call(conn, Plug.Logger.init(log: level))
    else
      conn
    end
  end

  @doc """
  Checks the origin request header against the list of allowed origins.

  Should be called by transports before connecting when appropriate.
  If the origin header matches the allowed origins, no origin header was
  sent or no origin was configured, it will return the given connection.

  Otherwise a 403 Forbidden response will be sent and the connection halted.
  It is a noop if the connection has been halted.
  """
  def check_origin(conn, handler, endpoint, opts, sender \\ &Plug.Conn.send_resp/1)

  def check_origin(%Plug.Conn{halted: true} = conn, _handler, _endpoint, _opts, _sender),
    do: conn

  def check_origin(conn, handler, endpoint, opts, sender) do
    import Plug.Conn
    origin       = conn |> get_req_header("origin") |> List.first()
    check_origin = check_origin_config(handler, endpoint, opts)

    cond do
      is_nil(origin) or check_origin == false ->
        conn

      origin_allowed?(check_origin, URI.parse(origin), endpoint) ->
        conn

      true ->
        Logger.error """
        Could not check origin for Phoenix.Socket transport.

        Origin of the request: #{origin}

        This happens when you are attempting a socket connection to
        a different host than the one configured in your config/
        files. For example, in development the host is configured
        to "localhost" but you may be trying to access it from
        "127.0.0.1". To fix this issue, you may either:

          1. update [url: [host: ...]] to your actual host in the
             config file for your current environment (recommended)

          2. pass the :check_origin option when configuring your
             endpoint or when configuring the transport in your
             UserSocket module, explicitly outlining which origins
             are allowed:

                check_origin: ["https://example.com",
                               "//another.com:888", "//other.com"]

        """
        resp(conn, :forbidden, "")
        |> sender.()
        |> halt()
    end
  end

  @doc """
  Extracts connection information from `conn` and returns a map.

  Keys are retrieved from the optional transport option `:connect_info`.
  This functionality is transport specific. Please refer to your transports'
  documentation for more information.

  The supported keys are:

    * `:peer_data` - the result of `Plug.Conn.get_peer_data/1`
    * `:x_headers` - a list of all request headers that have an "x-" prefix
    * `:uri` - a `%URI{}` derived from the conn

  """
  def connect_info(conn, keys) do
    for key <- keys, into: %{} do
      case key do
        :peer_data ->
          {:peer_data, Plug.Conn.get_peer_data(conn)}

        :x_headers ->
          {:x_headers, fetch_x_headers(conn)}

        :uri ->
          {:uri, fetch_uri(conn)}

        {key, val} -> {key, val}

        _ ->
          raise ArgumentError, ":connect_info keys are expected to be one of :peer_data, :x_headers, or :uri, optionally followed by custom keyword pairs, got: #{inspect(key)}"
      end
    end
  end

  defp fetch_x_headers(conn) do
    for {header, _} = pair <- conn.req_headers,
        String.starts_with?(header, "x-"),
        do: pair
  end

  defp fetch_uri(%{host: host, scheme: scheme, query_string: query_string, port: port, request_path: request_path}) do
    %URI{
      scheme: to_string(scheme),
      query: query_string,
      port: port,
      host: host,
      authority: host,
      path: request_path,
    }
  end

  defp check_origin_config(handler, endpoint, opts) do
    Phoenix.Config.cache(endpoint, {:check_origin, handler}, fn _ ->
      check_origin =
        case Keyword.get(opts, :check_origin, endpoint.config(:check_origin)) do
          origins when is_list(origins) ->
            Enum.map(origins, &parse_origin/1)

          boolean when is_boolean(boolean) ->
            boolean

          {module, function, arguments} ->
            {module, function, arguments}

          invalid ->
            raise ArgumentError, ":check_origin expects a boolean, list of hosts, or MFA tuple, got: #{inspect(invalid)}"
        end

      {:cache, check_origin}
    end)
  end

  defp parse_origin(origin) do
    case URI.parse(origin) do
      %{host: nil} ->
        raise ArgumentError,
          "invalid :check_origin option: #{inspect origin}. " <>
          "Expected an origin with a host that is parsable by URI.parse/1. For example: " <>
          "[\"https://example.com\", \"//another.com:888\", \"//other.com\"]"

      %{scheme: scheme, port: port, host: host} ->
        {scheme, host, port}
    end
  end

  defp origin_allowed?({module, function, arguments}, uri, _endpoint),
    do: apply(module, function, [uri | arguments])
  defp origin_allowed?(_check_origin, %{host: nil}, _endpoint),
    do: false
  defp origin_allowed?(true, uri, endpoint),
    do: compare?(uri.host, host_to_binary(endpoint.config(:url)[:host]))
  defp origin_allowed?(check_origin, uri, _endpoint) when is_list(check_origin),
    do: origin_allowed?(uri, check_origin)

  defp origin_allowed?(uri, allowed_origins) do
    %{scheme: origin_scheme, host: origin_host, port: origin_port} = uri

    Enum.any?(allowed_origins, fn {allowed_scheme, allowed_host, allowed_port} ->
      compare?(origin_scheme, allowed_scheme) and
      compare?(origin_port, allowed_port) and
      compare_host?(origin_host, allowed_host)
    end)
  end

  defp compare?(request_val, allowed_val) do
    is_nil(allowed_val) or request_val == allowed_val
  end

  defp compare_host?(_request_host, nil),
    do: true
  defp compare_host?(request_host, "*." <> allowed_host),
    do: String.ends_with?(request_host, allowed_host)
  defp compare_host?(request_host, allowed_host),
    do: request_host == allowed_host

  # TODO: Deprecate {:system, env_var} once we require Elixir v1.7+
  defp host_to_binary({:system, env_var}), do: host_to_binary(System.get_env(env_var))
  defp host_to_binary(host), do: host
end
