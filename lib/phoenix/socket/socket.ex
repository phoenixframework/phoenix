defmodule Phoenix.Socket do
  alias Phoenix.Socket

  defstruct conn: nil,
            pid: nil,
            channel: nil,
            topic: nil,
            router: nil,
            channels: [],
            assigns: []

  def set_current_channel(socket, channel, topic) do
    %Socket{socket | channel: channel, topic: topic}
  end

  def add_channel(socket, channel, topic) do
    %Socket{socket | channels: [{channel, topic} | socket.channels]}
  end

  def delete_channel(socket, channel, topic) do
    %Socket{socket | channels: List.delete(socket.channels, {channel, topic})}
  end

  def authenticated?(socket, channel, topic) do
    Enum.member? socket.channels, {channel, topic}
  end
end


