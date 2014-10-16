defmodule Phoenix.Channel.WebSocketTransport do
  use Phoenix.Controller
  use Phoenix.WebSocket

  alias Phoenix.Channel.Transport
  alias Phoenix.Socket
  alias Phoenix.Socket.Message
  alias Poison, as: JSON

  plug :action

  def upgrade_conn(conn, _) do
    upgrade(conn, websocket: __MODULE__)
  end

  @doc """
  Handles initalization of the websocket
  """
  def ws_init(conn) do
    {:ok, %Socket{pid: self, router: router_module(conn)}}
  end

  def ws_handle(text, socket) do
    text
    |> Message.parse!
    |> Transport.dispatch(socket)
  end

  @doc """
  Receives %Message{} and sends encoded message JSON to client
  """
  def ws_info(message = %Message{}, socket) do
    reply(socket.pid, JSON.encode!(message))
    socket
  end

  @doc """
  Handles regular messages sent to the socket process

  Each message is forwarded to the "info" event of the socket's authorized channels
  """
  def ws_info(data, socket) do
    Transport.dispatch_info(socket, data)
  end

  @doc """
  This is called right before the websocket is about to be closed.
  """
  def ws_terminate(reason, socket) do
    Transport.dispatch_leave(socket, reason)
    :ok
  end
end
