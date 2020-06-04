defmodule Phoenix.Transports.WebSocket do
  @moduledoc false
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

  def connect(%{method: "GET"} = conn, endpoint, handler, opts) do
    conn
    |> Plug.Conn.fetch_query_params()
    |> Transport.code_reload(endpoint, opts)
    |> Transport.transport_log(opts[:transport_log])
    |> Transport.force_ssl(handler, endpoint, opts)
    |> Transport.check_origin(handler, endpoint, opts)
    |> Transport.check_subprotocols(opts[:subprotocols])
    |> case do
      %{halted: true} = conn ->
        {:error, conn}

      %{params: params} = conn ->
        keys = Keyword.get(opts, :connect_info, [])
        connect_info = Transport.connect_info(conn, endpoint, keys)
        config = %{endpoint: endpoint, transport: :websocket, options: opts, params: params, connect_info: connect_info}

        case handler.connect(config) do
          {:ok, state} -> {:ok, conn, state}
          :error -> {:error, Plug.Conn.send_resp(conn, 403, "")}
          {:error, reason} ->
            {m, f, args} = opts[:error_handler]
            {:error, apply(m, f, [conn, reason | args])}
        end
    end
  end

  def connect(conn, _, _, _) do
    {:error, Plug.Conn.send_resp(conn, 400, "")}
  end

  def handle_error(conn, _reason), do: Plug.Conn.send_resp(conn, 403, "")
end
