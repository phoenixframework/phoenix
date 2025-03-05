defmodule Phoenix.Socket.Transport do
  @moduledoc """
  Outlines the Socket <-> Transport communication.

  Each transport, such as websockets and longpolling, must interact
  with a socket. This module defines the functions a transport will
  invoke on a given socket implementation.

  `Phoenix.Socket` is just one possible implementation of a socket
  that multiplexes events over multiple channels. If you implement
  this behaviour, then existing transports can use your new socket
  implementation, without passing through channels.

  This module also provides guidelines and convenience functions for
  implementing transports. Albeit its primary goal is to aid in the
  definition of custom sockets.

  ## Example

  Here is a simple echo socket implementation:

      defmodule EchoSocket do
        @behaviour Phoenix.Socket.Transport

        def child_spec(opts) do
          # We won't spawn any process, so let's ignore the child spec
          :ignore
        end

        def connect(state) do
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

  ## Custom transports

  Sockets are operated by a transport. When a transport is defined,
  it usually receives a socket module and the module will be invoked
  when certain events happen at the transport level. The functions
  a transport can invoke are the callbacks defined in this module.

  Whenever the transport receives a new connection, it should invoke
  the `c:connect/1` callback with a map of metadata. Different sockets
  may require different metadata.

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

  ### Booting

  When you list a socket under `Phoenix.Endpoint.socket/3`, Phoenix
  will automatically start the socket module under its supervision tree,
  however Phoenix does not manage any transport.

  Whenever your endpoint starts, Phoenix invokes the `child_spec/1` on
  each listed socket and start that specification under the endpoint
  supervisor. Since the socket supervision tree is started by the endpoint,
  any custom transport must be started after the endpoint.
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

  `:ignore` means no child spec is necessary for this socket.
  """
  @callback child_spec(keyword) :: :supervisor.child_spec() | :ignore

  @doc """
  Returns a child specification for terminating the socket.

  This is a process that is started late in the supervision
  tree with the specific goal of draining connections on
  application shutdown.

  Similar to `child_spec/1`, it receives the socket options
  from the endpoint.
  """
  @callback drainer_spec(keyword) :: :supervisor.child_spec() | :ignore

  @doc """
  Connects to the socket.

  The transport passes a map of metadata and the socket
  returns `{:ok, state}`, `{:error, reason}` or `:error`.
  The state must be stored by the transport and returned
  in all future operations. When `{:error, reason}` is
  returned, some transports - such as WebSockets - allow
  customizing the response based on `reason` via a custom
  `:error_handler`.

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
  @callback connect(transport_info :: map) :: {:ok, state} | {:error, term()} | :error

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

  Control frames are only supported when using websockets.

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

  @optional_callbacks handle_control: 2, drainer_spec: 1

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
      if config[:auth_token] do
        # auth_token is included by default when enabled
        [:auth_token | connect_info]
      else
        connect_info
      end

    connect_info =
      Enum.map(connect_info, fn
        key when key in [:peer_data, :trace_context_headers, :uri, :user_agent, :x_headers, :sec_websocket_headers, :auth_token] ->
          key

        {:session, session} ->
          {:session, init_session(session)}

        {_, _} = pair ->
          pair

        other ->
          raise ArgumentError,
                ":connect_info keys are expected to be one of :peer_data, :trace_context_headers, :x_headers, :user_agent, :sec_websocket_headers, :uri, or {:session, config}, " <>
                  "optionally followed by custom keyword pairs, got: #{inspect(other)}"
      end)

    [connect_info: connect_info] ++ config
  end

  # The original session_config is returned in addition to init value so we can
  # access special config like :csrf_token_key downstream.
  defp init_session(session_config) when is_list(session_config) do
    key = Keyword.fetch!(session_config, :key)
    store = Plug.Session.Store.get(Keyword.fetch!(session_config, :store))
    init = store.init(Keyword.drop(session_config, [:store, :key]))
    csrf_token_key = Keyword.get(session_config, :csrf_token_key, "_csrf_token")
    {key, store, {csrf_token_key, init}}
  end

  defp init_session({_, _, _} = mfa) do
    {:mfa, mfa}
  end

  @doc """
  Runs the code reloader if enabled.
  """
  def code_reload(conn, endpoint, opts) do
    if Keyword.get(opts, :code_reloader, endpoint.config(:code_reloader)) do
      Phoenix.CodeReloader.reload(endpoint)
    end

    conn
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
    origin = conn |> get_req_header("origin") |> List.first()
    check_origin = check_origin_config(handler, endpoint, opts)

    cond do
      is_nil(origin) or check_origin == false ->
        conn

      origin_allowed?(check_origin, URI.parse(origin), endpoint, conn) ->
        conn

      true ->
        Logger.error("""
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

        """)

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

        subprotocol =
          Enum.find(subprotocols, fn elem -> Enum.find(request_subprotocols, &(&1 == elem)) end)

        if subprotocol do
          Plug.Conn.put_resp_header(conn, "sec-websocket-protocol", subprotocol)
        else
          subprotocols_error_response(conn, subprotocols)
        end
    end
  end

  def check_subprotocols(conn, subprotocols), do: subprotocols_error_response(conn, subprotocols)

  defp subprotocols_error_response(conn, subprotocols) do
    import Plug.Conn
    request_headers = get_req_header(conn, "sec-websocket-protocol")

    Logger.error("""
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
    """)

    resp(conn, :forbidden, "")
    |> send_resp()
    |> halt()
  end

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

    * `:sec_websocket_headers` - a list of all request headers that have a "sec-websocket-" prefix

  The CSRF check can be disabled by setting the `:check_csrf` option to `false`.
  """
  def connect_info(conn, endpoint, keys, opts \\ []) do
    for key <- keys, into: %{} do
      case key do
        :peer_data ->
          {:peer_data, Plug.Conn.get_peer_data(conn)}

        :trace_context_headers ->
          {:trace_context_headers, fetch_trace_context_headers(conn)}

        :x_headers ->
          {:x_headers, fetch_headers(conn, "x-")}

        :uri ->
          {:uri, fetch_uri(conn)}

        :user_agent ->
          {:user_agent, fetch_user_agent(conn)}

        :sec_websocket_headers ->
          {:sec_websocket_headers, fetch_headers(conn, "sec-websocket-")}

        {:session, session} ->
          {:session, connect_session(conn, endpoint, session, opts)}

        :auth_token ->
          {:auth_token, conn.private[:phoenix_transport_auth_token]}

        {key, val} ->
          {key, val}
      end
    end
  end

  defp connect_session(conn, endpoint, {key, store, {csrf_token_key, init}}, opts) do
    conn = Plug.Conn.fetch_cookies(conn)
    check_csrf = Keyword.get(opts, :check_csrf, true)

    with cookie when is_binary(cookie) <- conn.cookies[key],
         conn = put_in(conn.secret_key_base, endpoint.config(:secret_key_base)),
         {_, session} <- store.get(conn, cookie, init),
         true <- not check_csrf or csrf_token_valid?(conn, session, csrf_token_key) do
      session
    else
      _ -> nil
    end
  end

  defp connect_session(conn, endpoint, {:mfa, {module, function, args}}, opts) do
    case apply(module, function, args) do
      session_config when is_list(session_config) ->
        connect_session(conn, endpoint, init_session(session_config), opts)

      other ->
        raise ArgumentError,
              "the MFA given to `session_config` must return a keyword list, got: #{inspect(other)}"
    end
  end

  defp fetch_headers(conn, prefix) do
    for {header, _} = pair <- conn.req_headers,
        String.starts_with?(header, prefix),
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

  defp csrf_token_valid?(conn, session, csrf_token_key) do
    with csrf_token when is_binary(csrf_token) <- conn.params["_csrf_token"],
         csrf_state when is_binary(csrf_state) <-
           Plug.CSRFProtection.dump_state_from_session(session[csrf_token_key]) do
      Plug.CSRFProtection.valid_state_and_csrf_token?(csrf_state, csrf_token)
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

          :conn ->
            :conn

          invalid ->
            raise ArgumentError,
                  ":check_origin expects a boolean, list of hosts, :conn, or MFA tuple, got: #{inspect(invalid)}"
        end

      {:cache, check_origin}
    end)
  end

  defp parse_origin(origin) do
    case URI.parse(origin) do
      %{host: nil} ->
        raise ArgumentError,
              "invalid :check_origin option: #{inspect(origin)}. " <>
                "Expected an origin with a host that is parsable by URI.parse/1. For example: " <>
                "[\"https://example.com\", \"//another.com:888\", \"//other.com\"]"

      %{scheme: scheme, port: port, host: host} ->
        {scheme, host, port}
    end
  end

  defp origin_allowed?({module, function, arguments}, uri, _endpoint, _conn),
    do: apply(module, function, [uri | arguments])

  defp origin_allowed?(:conn, uri, _endpoint, %Plug.Conn{} = conn) do
    uri.host == conn.host and
      uri.scheme == Atom.to_string(conn.scheme) and
      uri.port == conn.port
  end

  defp origin_allowed?(_check_origin, %{host: nil}, _endpoint, _conn),
    do: false

  defp origin_allowed?(true, uri, endpoint, _conn),
    do: compare?(uri.host, host_to_binary(endpoint.config(:url)[:host]))

  defp origin_allowed?(check_origin, uri, _endpoint, _conn) when is_list(check_origin),
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
    do: request_host == allowed_host or String.ends_with?(request_host, "." <> allowed_host)

  defp compare_host?(request_host, allowed_host),
    do: request_host == allowed_host

  # TODO: Remove this once {:system, env_var} deprecation is removed
  defp host_to_binary({:system, env_var}), do: host_to_binary(System.get_env(env_var))
  defp host_to_binary(host), do: host
end
