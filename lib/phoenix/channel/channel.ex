defmodule Phoenix.Channel do
  alias Phoenix.Topic
  alias Phoenix.Socket

  defmacro __using__(options) do
    quote do
      import unquote(__MODULE__)
    end
  end

  @doc """
  Subscribes socket to given topic based on current multiplexed channel
  """
  def subscribe(socket, topic) do
    Topic.subscribe(socket.pid, namespaced(socket.channel, topic))
  end

  @doc """
  Broadcast Dict message, serializable as JSON to topic namedspaced by channel

  Examples

  iex> Channel.broadcast "messages", "create", id: 1, content: "hello"
  :ok
  iex> Channel.broadcast socket, "create", id: 1, content: "hello"
  :ok
  """
  def broadcast(channel, topic, message) when is_binary(channel) do
    broadcast_from :global, channel, topic, message
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

  @doc """
  Sends Dict, JSON serializable message to socket
  """
  def reply(socket, message) do
    # TODO: Needs to be channel/topic namespaced
    send socket.pid, {:reply, {:text, JSON.encode!(message)}}
    {:ok, socket}
  end

  def reply_json(message) do
    {:reply, {:text, JSON.encode!(message)}}
  end

  defp namespaced(channel, topic), do: "#{channel}:#{topic}"
end
