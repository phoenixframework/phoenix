defmodule Phoenix.Socket.Router do
  # Routes WebSocket and LongPoller requests.
  @moduledoc false

  import Plug.Conn
  require Logger
  alias Phoenix.Transports.WebSocket
  alias Phoenix.Transports.LongPoller

  def init(opts), do: opts

  def call(conn, module) do
    conn = conn |> fetch_query_params() |> put_private(:phoenix_socket, module)
    transport = case conn.query_params["transport"] do
      "poll" -> LongPoller
      _      -> WebSocket
    end

    case {conn.method, transport} do
      {"GET",  WebSocket}     -> WebSocket.call(conn, [])
      {"POST", WebSocket}     -> WebSocket.call(conn, [])
      {"OPTIONS", LongPoller} -> LongPoller.call(conn, :options)
      {"GET", LongPoller}     -> LongPoller.call(conn, :poll)
      {"POST", LongPoller}    -> LongPoller.call(conn, :publish)
      _                       -> conn |> send_resp(:bad_request, "") |> halt()
    end
  end
end
