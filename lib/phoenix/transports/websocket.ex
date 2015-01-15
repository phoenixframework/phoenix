defmodule Phoenix.Transports.WebSocket do
  use Phoenix.Controller

  @moduledoc """
  Handles WebSocket clients for the Channel Transport layer

  ## Configuration

  By default, JSON encoding is used to broker messages to and from clients,
  but the serializer is configurable via the Endpoint's transport configuration:

      config :my_app, MyApp.Endpoint, transports: [
        websocket_serializer: MySerializer
      ]

  The `websocket_serializer` module needs only to implement the `encode!/1` and
  `decode!/2` functions defined by the `Phoenix.Transports.Serializer` behaviour.

  Websockets, by default, do not timeout if the connection is lost. To set a
  maximum timeout duration in milliseconds, add this to your Endpoint's transport
  configuration:

      config :my_app, MyApp.Endpoint, transports: [
        websocket_timeout: 60000
      ]
  """

  alias Phoenix.Channel.Transport
  alias Phoenix.Socket.Message
  alias Phoenix.Transports.LongPoller

  plug :action

  def upgrade(%Plug.Conn{method: "GET"} = conn, _) do
    put_private(conn, :phoenix_upgrade, {:websocket, __MODULE__}) |> halt
  end
  def upgrade(%Plug.Conn{method: "POST"} = conn, _) do
    LongPoller.call(conn, LongPoller.init(:open))
  end

  @doc """
  Handles initalization of the websocket
  """
  def ws_init(conn) do
    serializer = Dict.fetch!(endpoint_module(conn).config(:transports), :websocket_serializer)
    timeout = Dict.fetch!(endpoint_module(conn).config(:transports), :websocket_timeout)
    {:ok, %{router: router_module(conn), sockets: HashDict.new, serializer: serializer}, timeout}
  end

  @doc """
  Receives JSON encoded `%Phoenix.Socket.Message{}` from client and dispatches
  to Transport layer
  """
  def ws_handle(opcode, payload, state = %{router: router, sockets: sockets, serializer: serializer}) do
    payload
    |> serializer.decode!(opcode)
    |> Transport.dispatch(sockets, self, router, __MODULE__)
    |> case do
      {:ok, sockets}             -> %{state | sockets: sockets}
      {:error, sockets, _reason} -> %{state | sockets: sockets}
    end
  end

  @doc """
  Receives `%Phoenix.Socket.Message{}` and sends encoded message JSON to client
  """
  def ws_info({:socket_broadcast, message = %Message{}}, state = %{sockets: sockets}) do
    sockets = case Transport.dispatch_broadcast(sockets, message) do
      {:ok, socks} -> socks
      {:error, socks, _reason} -> socks
    end

    %{state | sockets: sockets}
  end
  def ws_info({:socket_reply, message = %Message{}}, state = %{serializer: serializer}) do
    reply(self, serializer.encode!(message))
    state
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
