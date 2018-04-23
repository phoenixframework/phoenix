defmodule Phoenix.Transports.WebSocket do
  @moduledoc false

  _ = """
  Socket transport for websocket clients.

  ## Configuration

  The websocket is configurable in your socket:

      transport :websocket, Phoenix.Transports.WebSocket,
        timeout: :infinity,
        transport_log: false

    * `:timeout` - the timeout for keeping websocket connections
      open after it last received data, defaults to 60_000ms

    * `:transport_log` - if the transport layer itself should log and, if so, the level

    * `:serializer` - the serializer for websocket messages

    * `:check_origin` - if we should check the origin of requests when the
      origin header is present. It defaults to true and, in such cases,
      it will check against the host value in `YourApp.Endpoint.config(:url)[:host]`.
      It may be set to `false` (not recommended) or to a list of explicitly
      allowed origins.

      check_origin: ["https://example.com",
                     "//another.com:888", "//other.com"]

      Note: To connect from a native app be sure to either have the native app
      set an origin or allow any origin via `check_origin: false`

    * `:code_reloader` - optionally override the default `:code_reloader` value
      from the socket's endpoint

  ## Serializer

  By default, JSON encoding is used to broker messages to and from clients.
  A custom serializer may be given as a module which implements the `encode!/1`
  and `decode!/2` functions defined by the `Phoenix.Transports.Serializer`
  behaviour.

  The `encode!/1` function must return a tuple in the format
  `{:socket_push, :text | :binary, String.t | binary}`.

  ## Garbage collection

  It's possible to force garbage collection in the transport process after
  processing large messages.

  Send `:garbage_collect` clause to the transport process:

      send socket.transport_pid, :garbage_collect
  """

  def default_config() do
    [serializer: [{Phoenix.Transports.WebSocketSerializer, "~> 1.0.0"},
                  {Phoenix.Socket.V2.JSONSerializer, "~> 2.0.0"}],
     timeout: 60_000,
     transport_log: false,
     compress: false]
  end

  ## Callbacks

  import Plug.Conn, only: [fetch_query_params: 1, send_resp: 3]
  alias Phoenix.Socket.Transport

  @doc false
  def init(%Plug.Conn{method: "GET"} = conn, {endpoint, handler, transport, opts}) do
    conn =
      conn
      |> fetch_query_params()
      |> Transport.code_reload(endpoint, opts)
      |> Transport.transport_log(opts[:transport_log])
      |> Transport.force_ssl(handler, endpoint, opts)
      |> Transport.check_origin(handler, endpoint, opts)

    case conn do
      %{halted: false} = conn ->
        params     = conn.params
        serializer = Keyword.fetch!(opts, :serializer)

        case Transport.connect(endpoint, handler, transport, __MODULE__, serializer, params) do
          {:ok, state} ->
            {:ok, conn, state}
          :error ->
            conn = send_resp(conn, 403, "")
            {:error, conn}
        end
      %{halted: true} = conn ->
        {:error, conn}
    end
  end

  def init(conn, _) do
    conn = send_resp(conn, 400, "")
    {:error, conn}
  end
end
