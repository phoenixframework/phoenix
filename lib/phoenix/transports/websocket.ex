defmodule Phoenix.Transports.WebSocket do
  @moduledoc false
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
            conn
            |> WebSock.upgrade(handler, arg, opts)
            |> halt()

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
