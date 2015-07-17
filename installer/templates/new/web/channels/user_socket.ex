defmodule <%= application_module %>.UserSocket do
  use Phoenix.Socket

  ## Channels
  # channel "rooms:*", <%= application_module %>.RoomChannel

  ## Transports
  transport :websocket, Phoenix.Transports.WebSocket
  # transport :longpoll, Phoenix.Transports.LongPoll

  @doc """
  Authenticates the socket connection.
  """
  def connect(params, socket) do
    {:ok, socket}
  end

  @doc """
  Identifies the socket connection.
  """
  def id(_socket), do: nil
end
