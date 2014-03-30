defmodule Phoenix.Channel do
  alias Phoenix.Topic

  def subscribe(topic, socket) do
    Topic.subscribe(topic, socket.pid)
  end

  def broadcast(topic, message) do
    broadcast_from :global, topic, message
  end

  def broadcast_from(pid, topic, message) do
    Topic.broadcast_from(pid, topic, {:reply, {:text, JSON.encode!(message)}})
  end

  def reply(socket, message) do
    send socket.pid, {:reply, {:text, JSON.encode!(message)}}
    {:ok, socket}
  end
end
