defmodule Phoenix.Socket.Router do
  # Routes WebSocket and LongPoller requests.
  @moduledoc false

  use Plug.Builder
  alias Phoenix.Transports.WebSocket
  alias Phoenix.Transports.LongPoller

  @longpoll "longpoll"
  @websocket "websocket"

  plug Plug.Logger
  plug :fetch_query_params
  plug :transport_dispatch

  def transport_dispatch(conn, _) do
    dispatch(conn, conn.method, conn.private.phoenix_socket_transport)
  end

  defp dispatch(conn, method, @websocket) when method in ["GET", "POST"] do
    WebSocket.call(conn, [])
  end

  defp dispatch(conn, "OPTIONS", @longpoll) do
    LongPoller.call(conn, :options)
  end
  defp dispatch(conn, "GET", @longpoll) do
    LongPoller.call(conn, :poll)
  end
  defp dispatch(conn, "POST", @longpoll) do
    LongPoller.call(conn, :publish)
  end

  defp dispatch(conn, _method, _transport) do
    conn |> send_resp(:bad_request, "") |> halt()
  end
end
