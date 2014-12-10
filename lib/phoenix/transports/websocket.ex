defmodule Phoenix.Transports.WebSocket do
  use Phoenix.Controller

  @moduledoc """
  Handles WebSocket clients for the Channel Transport layer

  ## Configuration

  By default, JSON encoding is used to broker messages to and from clients,
  but the serializer is configurable via the Router's transport configuration:

      config :my_app, MyApp.Router, transports: [
        websocket_serializer: MySerializer
      ]

  The `websocket_serializer` module needs only to implement the `encode!/1` and
  `decode!/2` functions defined by the `Phoenix.Transports.Serializer` behaviour.
  """

  alias Phoenix.Channel.Transport
  alias Phoenix.Socket.Message

  plug :action

  def upgrade_conn(conn, _) do
    put_private(conn, :phoenix_upgrade, {:websocket, __MODULE__}) |> halt
  end

  @doc """
  Handles initalization of the websocket
  """
  def ws_init(conn) do
    serializer = Dict.fetch!(endpoint_module(conn).config(:transports), :websocket_serializer)
    {:ok, %{router: router_module(conn), sockets: HashDict.new, serializer: serializer}}
  end

  @doc """
  Receives JSON encoded `%Phoenix.Socket.Message{}` from client and dispatches
  to Transport layer
  """
  def ws_handle(opcode, payload, state = %{router: router, sockets: sockets, serializer: serializer}) do
    payload
    |> serializer.decode!(opcode)
    |> Transport.dispatch(sockets, self, router)
    |> case do
      {:ok, sockets}             -> %{state | sockets: sockets}
      {:error, sockets, _reason} -> %{state | sockets: sockets}
    end
  end

  @doc """
  Receives `%Phoenix.Socket.Message{}` and sends encoded message JSON to client
  """
  def ws_info(message = %Message{}, state = %{serializer: serializer}) do
    reply(self, serializer.encode!(message))
    state
  end

  @doc """
  Handles Elixir messages sent to the socket process

  Dispatches `"info"` event back through Tranport layer to all socket's channels
  """
  def ws_info(data, state = %{sockets: sockets}) do
    sockets = case Transport.dispatch_info(sockets, data) do
      {:ok, socks} -> socks
      {:error, socks, _reason} -> socks
    end

    %{state | sockets: sockets}
  end

  @doc """
  Called on WS close. Dispatches the `leave` event back through Transport layer
  """
  def ws_terminate(reason, %{sockets: sockets}) do
    :ok = Transport.dispatch_leave(sockets, reason)
    :ok
  end

  def ws_hibernate(_state), do: :ok

  defp reply(pid, msg) do
    send(pid, {:reply, msg})
  end
end
