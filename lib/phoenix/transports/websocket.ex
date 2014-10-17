defmodule Phoenix.Transports.WebSocket do
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

  @doc """
  Receives JSON encoded `%Message{}` from client and dispatches to Transport layer
  """
  def ws_handle(text, socket) do
    text
    |> Message.parse!
    |> Transport.dispatch(socket)
    |> case do
      {:ok, socket} -> socket
      {:error, socket, _reason} -> socket
    end
  end

  @doc """
  Receives `%Message{}` and sends encoded message JSON to client
  """
  def ws_info(message = %Message{}, socket) do
    reply(socket.pid, JSON.encode!(message))
    socket
  end

  @doc """
  Handles Elixir messages sent to the socket process

  Dispatches `"info"` event back through Tranport layer to all socket's channels
  """
  def ws_info(data, socket) do
    case Transport.dispatch_info(socket, data) do
      {:ok, socket} -> socket
      {:error, socket, _reason} -> socket
    end
  end

  @doc """
  Called on WS close. Dispatches the `leave` event back through Transport layer
  """
  def ws_terminate(reason, socket) do
    :ok = Transport.dispatch_leave(socket, reason)
    :ok
  end
end
