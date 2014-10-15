defmodule Phoenix.Channel.WebSocketTransport do
  use Phoenix.WebSocket

  @behaviour Phoenix.Channel.Transport

  alias Phoenix.Channel.Transport
  alias Phoenix.Socket.Message
  alias Poison, as: JSON


  def start_link(opts) do
    :ok
  end


  @doc """
  Handles initalization of the websocket
  """
  def init(opts) do
    router = Dict.fetch! opts, :router

    {:ok, %Socket{pid: self, router: router}}
  end

  def ws_handle(text, _req, socket) do
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
  def ws_terminate(reason, _req, socket) do
    Transport.dispatch_leave(socket, reason)
    :ok
  end
end
