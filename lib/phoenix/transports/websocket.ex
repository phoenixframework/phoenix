defmodule Phoenix.Transports.WebSocket do
  use Phoenix.Controller
  use Phoenix.WebSocket

  @moduledoc false

  alias Phoenix.Channel.Transport
  alias Phoenix.Socket.Message
  alias Poison, as: JSON

  plug :action

  def upgrade_conn(conn, _) do
    put_private(conn, :phoenix_upgrade, {:websocket, __MODULE__}) |> halt
  end

  @doc """
  Handles initalization of the websocket
  """
  def ws_init(conn) do
    {:ok, {router_module(conn), HashDict.new}}
  end

  @doc """
  Receives JSON encoded `%Phoenix.Socket.Message{}` from client and dispatches
  to Transport layer
  """
  def ws_handle(text, {router, sockets}) do
    text
    |> Message.parse!
    |> Transport.dispatch(sockets, self, router)
    |> case do
      {:ok, sockets}             -> {router, sockets}
      {:error, sockets, _reason} -> {router, sockets}
    end
  end

  @doc """
  Receives `%Phoenix.Socket.Message{}` and sends encoded message JSON to client
  """
  def ws_info(message = %Message{}, state) do
    reply(self, JSON.encode!(message))
    state
  end

  @doc """
  Handles Elixir messages sent to the socket process

  Dispatches `"info"` event back through Tranport layer to all socket's channels
  """
  def ws_info(data, {router, sockets}) do
    {:ok, sockets} = case Transport.dispatch_info(sockets, data) do
      {:ok, socket} -> socket
      {:error, socket, _reason} -> socket
    end

    {router, sockets}
  end

  @doc """
  Called on WS close. Dispatches the `leave` event back through Transport layer
  """
  def ws_terminate(reason, {_router, sockets}) do
    :ok = Transport.dispatch_leave(sockets, reason)
    :ok
  end
end
