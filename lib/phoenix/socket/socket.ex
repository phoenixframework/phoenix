defmodule Phoenix.Socket do
  alias Phoenix.Socket

  defstruct conn: nil,
            pid: nil,
            channel: nil,
            router: nil,
            channels: [],
            assigns: []

  def set_current_channel(socket, channel) do
    %Socket{socket | channel: channel}
  end

  def add_channel(socket, channel) do
    %Socket{socket | channels: [channel | socket.channels]}
  end

  def delete_channel(socket, channel) do
    %Socket{socket | channels: List.delete(socket.channels, channel)}
  end

  def authenticated?(socket, channel) do
    Enum.member? socket.channels, channel
  end
end


