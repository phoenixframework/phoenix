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

  @connect_info_opts [:check_csrf]

  @auth_token_prefix "base64url.bearer.phx."

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
    subprotocols =
      if opts[:auth_token] do
        # when using Sec-WebSocket-Protocol for passing an auth token
        # the server must reply with one of the subprotocols in the request;
        # therefore we include "phoenix" as allowed subprotocol and include it on the client
        ["phoenix" | Keyword.get(opts, :subprotocols, [])]
      else
        opts[:subprotocols]
      end

    conn
    |> fetch_query_params()
    |> Transport.code_reload(endpoint, opts)
    |> Transport.transport_log(opts[:transport_log])
    |> Transport.check_origin(handler, endpoint, opts)
    |> maybe_auth_token_from_header(opts[:auth_token])
    |> Transport.check_subprotocols(subprotocols)
    |> case do
      %{halted: true} = conn ->
        conn

      %{params: params} = conn ->
        keys = Keyword.get(opts, :connect_info, [])

        connect_info =
          Transport.connect_info(conn, endpoint, keys, Keyword.take(opts, @connect_info_opts))

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

  defp maybe_auth_token_from_header(conn, true) do
    case get_req_header(conn, "sec-websocket-protocol") do
      [] ->
        conn

      [subprotocols_header | _] ->
        request_subprotocols =
          subprotocols_header
          |> Plug.Conn.Utils.list()
          |> Enum.split_with(&String.starts_with?(&1, @auth_token_prefix))

        case request_subprotocols do
          {[@auth_token_prefix <> encoded_token], actual_subprotocols} ->
            token = Base.decode64!(encoded_token, padding: false)

            conn
            |> put_private(:phoenix_transport_auth_token, token)
            |> set_actual_subprotocols(actual_subprotocols)

          _ ->
            conn
        end
    end
  end

  defp maybe_auth_token_from_header(conn, _), do: conn

  defp set_actual_subprotocols(conn, []), do: delete_req_header(conn, "sec-websocket-protocol")

  defp set_actual_subprotocols(conn, subprotocols),
    do: put_req_header(conn, "sec-websocket-protocol", Enum.join(subprotocols, ", "))
end
