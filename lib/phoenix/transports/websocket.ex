defmodule Phoenix.Transports.WebSocket do
  @moduledoc false
  #
  # How WebSockets Work In Phoenix
  #
  # WebSocket support in Phoenix is implemented on top of the `WebSockAdapter` library. Upgrade
  # requests from clients originate as regular HTTP requests that get routed to this module via
  # Plug. These requests are then upgraded to WebSocket connections via
  # `WebSockAdapter.upgrade/4`, which takes as an argument the handler for a given socket endpoint
  # as configured in the application's Endpoint. This handler module must implement the
  # transport-agnostic `Phoenix.Socket.Transport` behaviour (this same behaviour is also used for
  # other transports such as long polling). Because this behaviour is a superset of the `WebSock`
  # behaviour, the `WebSock` library is able to use the callbacks in the `WebSock` behaviour to
  # call this handler module directly for the rest of the WebSocket connection's lifetime.
  #
  @behaviour Plug

  import Plug.Conn

  alias Phoenix.Socket.{V1, V2, Transport}

  def default_config() do
    [
      path: "/websocket",
      serializer: [{V1.JSONSerializer, "~> 1.0.0"}, {V2.JSONSerializer, "~> 2.0.0"}],
      error_handler: {__MODULE__, :handle_error, []},
      timeout: 60_000,
      transport_log: false,
      compress: false
    ]
  end

  def init(opts), do: opts

  def call(%{method: "GET"} = conn, {endpoint, handler, opts}) do
    conn
    |> fetch_query_params()
    |> Transport.code_reload(endpoint, opts)
    |> Transport.transport_log(opts[:transport_log])
    |> Transport.check_origin(handler, endpoint, opts)
    |> Transport.check_subprotocols(opts[:subprotocols])
    |> case do
      %{halted: true} = conn ->
        conn

      %{params: params} = conn ->
        keys = Keyword.get(opts, :connect_info, [])
        connect_info = Transport.connect_info(conn, endpoint, keys)

        config = %{
          endpoint: endpoint,
          transport: :websocket,
          options: opts,
          params: params,
          connect_info: connect_info
        }

        case handler.connect(config) do
          {:ok, arg} ->
            try do
              conn
              |> WebSockAdapter.upgrade(handler, arg, opts)
              |> halt()
            rescue
              e in WebSockAdapter.UpgradeError -> send_resp(conn, 400, e.message)
            end

          :error ->
            send_resp(conn, 403, "")

          {:error, reason} ->
            {m, f, args} = opts[:error_handler]
            apply(m, f, [conn, reason | args])
        end
    end
  end

  def call(conn, _), do: send_resp(conn, 400, "")

  def handle_error(conn, _reason), do: send_resp(conn, 403, "")
end
