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
  many conveniences that invokes the underlying socket API to make
  it easier to build custom transports.

  ## Booting sockets

  Whenever your endpoint starts, it will automatically invoke the
  `child_spec/1` on each listed socket and start that specification
  under the endpoint supervisor.

  Since the socket supervision tree is started by the endpoint,
  any custom transport must be started after the endpoint in a
  supervision tree.

  ## Operating sockets

  Sockets are operated by a transport. When a transport is defined,
  it usually receives a socket module and the module will be invoked
  when certain events happen at the transport level.

  Whenever the transport receives a new connection, it should invoke
  the `c:connect/1` callback with a map of metadata. Different sockets
  may require different metadatas.

  If the connection is accepted, the transport can move the connection
  to another process, if so desires, or keep using the same process. The
  process responsible for managing the socket should then call `c:init/1`.

  For each message received from the client, the transport must call
  `c:handle_in/2` on the socket. For each informational message the
  transport receives, it should call `c:handle_info/2` on the socket.

  Transports can optionally implement `c:handle_control/2` for handling
  control frames such as `:ping` and `:pong`.

  On termination, `c:terminate/2` must be called. A special atom with
  reason `:closed` can be used to specify that the client terminated
  the connection.

  ## Example

  Here is a simple echo socket implementation:

      defmodule EchoSocket do
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

        def handle_in({text, _opts}, state) do
          {:reply, :ok, {:text, text}, state}
        end

        def handle_info(_, state) do
          {:ok, state}
        end

        def terminate(_reason, _state) do
          :ok
        end
      end

  It can be mounted in your endpoint like any other socket:

      socket "/socket", EchoSocket, websocket: true, longpoll: true

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
  Handles incoming control frames.

  The message is represented as `{payload, options}`. It must
  return one of:

    * `{:ok, state}` - continues the socket with no reply
    * `{:reply, status, reply, state}` - continues the socket with reply
    * `{:stop, reason, state}` - stops the socket

  Control frames only supported when using websockets.

  The `options` contains an `opcode` key, this will be either `:ping` or
  `:pong`.

  If a control frame doesn't have a payload, then the payload value
  will be `nil`.
  """
  @callback handle_control({message :: term, opts :: keyword}, state) ::
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

  If `reason` is `:closed`, it means the client closed the socket. This is
  considered a `:normal` exit signal, so linked process will not automatically
  exit. See `Process.exit/2` for more details on exit signals.
  """
  @callback terminate(reason :: term, state) :: :ok

  @optional_callbacks handle_control: 2

  require Logger

  @doc false
  def load_config(true, module),
    do: module.default_config()

  def load_config(config, module),
    do: module.default_config() |> Keyword.merge(config) |> load_config()

  @doc false
  def load_config(config) do
    {connect_info, config} = Keyword.pop(config, :connect_info, [])

    connect_info =
      Enum.map(connect_info, fn
        key when key in [:peer_data, :trace_context_headers, :uri, :user_agent, :x_headers] ->
          key

        {:session, session} ->
          {:session, init_session(session)}

        {_, _} = pair ->
          pair

        other ->
          raise ArgumentError,
                ":connect_info keys are expected to be one of :peer_data, :trace_context_headers, :x_headers, :uri, or {:session, config}, " <>
                  "optionally followed by custom keyword pairs, got: #{inspect(other)}"
      end)

    [connect_info: connect_info] ++ config
  end

  defp init_session(session_config) when is_list(session_config) do
    key = Keyword.fetch!(session_config, :key)
    store = Plug.Session.Store.get(Keyword.fetch!(session_config, :store))
    init = store.init(Keyword.drop(session_config, [:store, :key]))
    {key, store, init}
  end

  defp init_session({_, _, _} = mfa)  do
    {:mfa, mfa}
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
  Checks the Websocket subprotocols request header against the allowed subprotocols.

  Should be called by transports before connecting when appropriate.
  If the sec-websocket-protocol header matches the allowed subprotocols,
  it will put sec-websocket-protocol response header and return the given connection.
  If no sec-websocket-protocol header was sent it will return the given connection.

  Otherwise a 403 Forbidden response will be sent and the connection halted.
  It is a noop if the connection has been halted.
  """
  def check_subprotocols(conn, subprotocols)

  def check_subprotocols(%Plug.Conn{halted: true} = conn, _subprotocols), do: conn
  def check_subprotocols(conn, nil), do: conn

  def check_subprotocols(conn, subprotocols) when is_list(subprotocols) do
    case Plug.Conn.get_req_header(conn, "sec-websocket-protocol") do
      [] ->
        conn

      [subprotocols_header | _] ->
        request_subprotocols = subprotocols_header |> Plug.Conn.Utils.list()
        subprotocol = Enum.find(subprotocols, fn elem -> Enum.find(request_subprotocols, &(&1 == elem)) end)

        if subprotocol do
          Plug.Conn.put_resp_header(conn, "sec-websocket-protocol", subprotocol)
        else
          subprotocols_error_response(conn, subprotocols)
        end
    end
  end

  def check_subprotocols(conn, subprotocols), do: subprotocols_error_response(conn, subprotocols)

  @doc """
  Extracts connection information from `conn` and returns a map.

  Keys are retrieved from the optional transport option `:connect_info`.
  This functionality is transport specific. Please refer to your transports'
  documentation for more information.

  The supported keys are:

    * `:peer_data` - the result of `Plug.Conn.get_peer_data/1`

    * `:trace_context_headers` - a list of all trace context headers

    * `:x_headers` - a list of all request headers that have an "x-" prefix

    * `:uri` - a `%URI{}` derived from the conn

    * `:user_agent` - the value of the "user-agent" request header

  """
  def connect_info(conn, endpoint, keys) do
    for key <- keys, into: %{} do
      case key do
        :peer_data ->
          {:peer_data, Plug.Conn.get_peer_data(conn)}

        :trace_context_headers ->
          {:trace_context_headers, fetch_trace_context_headers(conn)}

        :x_headers ->
          {:x_headers, fetch_x_headers(conn)}

        :uri ->
          {:uri, fetch_uri(conn)}

        :user_agent ->
          {:user_agent, fetch_user_agent(conn)}

        {:session, session} ->
          {:session, connect_session(conn, endpoint, session)}

        {key, val} ->
          {key, val}
      end
    end
  end

  defp connect_session(conn, endpoint, {key, store, store_config}) do
    conn = Plug.Conn.fetch_cookies(conn)

    with csrf_token when is_binary(csrf_token) <- conn.params["_csrf_token"],
         cookie when is_binary(cookie) <- conn.cookies[key],
         conn = put_in(conn.secret_key_base, endpoint.config(:secret_key_base)),
         {_, session} <- store.get(conn, cookie, store_config),
         csrf_state when is_binary(csrf_state) <- Plug.CSRFProtection.dump_state_from_session(session["_csrf_token"]),
         true <- Plug.CSRFProtection.valid_state_and_csrf_token?(csrf_state, csrf_token) do
      session
    else
      _ -> nil
    end
  end

  defp connect_session(conn, endpoint, {:mfa, {module, function, args}}) do
    case apply(module, function, args) do
      session_config when is_list(session_config) ->
        connect_session(conn, endpoint, init_session(session_config))

      other ->
        raise ArgumentError,
          "the MFA given to `session_config` must return a keyword list, got: #{inspect other}"
    end
  end

  defp subprotocols_error_response(conn, subprotocols) do
    import Plug.Conn
    request_headers = get_req_header(conn, "sec-websocket-protocol")

    Logger.error """
    Could not check Websocket subprotocols for Phoenix.Socket transport.

    Subprotocols of the request: #{inspect(request_headers)}
    Configured supported subprotocols: #{inspect(subprotocols)}

    This happens when you are attempting a socket connection to
    a different subprotocols than the one configured in your endpoint
    or when you incorrectly configured supported subprotocols.

    To fix this issue, you may either:

      1. update websocket: [subprotocols: [..]] to your actual subprotocols
         in your endpoint socket configuration.

      2. check the correctness of the `sec-websocket-protocol` request header
         sent from the client.

      3. remove `websocket` option from your endpoint socket configuration
         if you don't use Websocket subprotocols.
    """

    resp(conn, :forbidden, "")
    |> send_resp()
    |> halt()
  end

  defp fetch_x_headers(conn) do
    for {header, _} = pair <- conn.req_headers,
        String.starts_with?(header, "x-"),
        do: pair
  end

  defp fetch_trace_context_headers(conn) do
    for {header, _} = pair <- conn.req_headers,
      header in ["traceparent", "tracestate"],
      do: pair
  end

  defp fetch_uri(conn) do
    %URI{
      scheme: to_string(conn.scheme),
      query: conn.query_string,
      port: conn.port,
      host: conn.host,
      authority: conn.host,
      path: conn.request_path
    }
  end

  defp fetch_user_agent(conn) do
    with {_, value} <- List.keyfind(conn.req_headers, "user-agent", 0) do
      value
    end
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

  # TODO: Deprecate {:system, env_var} once we require Elixir v1.9+
  defp host_to_binary({:system, env_var}), do: host_to_binary(System.get_env(env_var))
  defp host_to_binary(host), do: host
end
