defmodule Phoenix.Socket.Router do
  # Routes WebSocket and LongPoller requests.
  @moduledoc false

  use Plug.Builder
  alias Phoenix.Transports.WebSocket
  alias Phoenix.Transports.LongPoller

  plug Plug.Logger
  plug :fetch_query_params
  plug :dispatch

  def dispatch(conn, _) do
    case {conn.method, transport(conn)} do
      {"GET",  WebSocket}     -> WebSocket.call(conn, [])
      {"POST", WebSocket}     -> WebSocket.call(conn, [])
      {"OPTIONS", LongPoller} -> LongPoller.call(conn, :options)
      {"GET", LongPoller}     -> LongPoller.call(conn, :poll)
      {"POST", LongPoller}    -> LongPoller.call(conn, :publish)
      _                       -> conn |> send_resp(:bad_request, "") |> halt()
    end
  end

  defp transport(conn) do
    case conn.query_params["transport"] do
      "poll" -> LongPoller
      _      -> WebSocket
    end
  end
end
