defmodule Phoenix.Channel do
  alias Phoenix.Topic
  alias Phoenix.Socket

  defmacro __using__(options) do
    channel = Dict.fetch! options, :channel

    quote do
      import unquote(__MODULE__)
      @channel unquote(channel)

      def channel, do: @channel
    end
  end

  def namespaced_topic(topic), do: "#{__MODULE__}#{topic}"

  def subscribe(socket, channel, topic) do
    Topic.subscribe(socket.pid, namespaced(channel, topic))
  end

  def broadcast(channel, topic, message) do
    broadcast_from :global, channel, topic, message
  end

  def broadcast_from(:global, channel, topic, message) do
    Topic.broadcast_from :global,
                         namespaced(channel, topic),
                         reply_json(message)
  end
  def broadcast_from(socket, channel, topic, message) do
    Topic.broadcast_from socket.pid,
                         namespaced(channel, topic),
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
