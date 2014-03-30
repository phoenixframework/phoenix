defmodule Phoenix.Channel do
  alias Phoenix.Topic
  alias Phoenix.Socket

  defmacro __using__(options) do
    quote do
      import unquote(__MODULE__)
    end
  end

  def subscribe(socket, topic) do
    Topic.subscribe(socket.pid, namespaced(socket.channel, topic))
  end

  def broadcast(socket, topic, message) do
    broadcast_from :global, socket.channel, topic, message
  end

  def broadcast_from(:global, channel, topic, message) do
    Topic.broadcast_from :global,
                         namespaced(channel, topic),
                         reply_json(message)
  end
  def broadcast_from(socket, topic, message) do
    Topic.broadcast_from socket.pid,
                         namespaced(socket.channel, topic),
                         reply_json(message)
  end

  def reply(socket, message) do
    send socket.pid, {:reply, {:text, JSON.encode!(message)}}
    {:ok, socket}
  end

  def reply_json(message) do
    {:reply, {:text, JSON.encode!(message)}}
  end

  defp namespaced(channel, topic), do: "#{channel}:#{topic}"
end
