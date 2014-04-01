defmodule Phoenix.Channel do
  alias Phoenix.Topic
  alias Phoenix.Socket

  defmacro __using__(options) do
    quote do
      import unquote(__MODULE__)
    end
  end

  @doc """
  Subscribes socket to given channel topic
  """
  def subscribe(socket, channel, topic) do
    Topic.subscribe(socket.pid, namespaced(channel, topic))
  end

  @doc """
  Broadcast Dict message, serializable as JSON to topic namedspaced by channel

  Examples

  iex> Channel.broadcast "messages", "create", id: 1, content: "hello"
  :ok
  iex> Channel.broadcast socket, "create", id: 1, content: "hello"
  :ok
  """
  def broadcast(channel, topic, event, message) when is_binary(channel) do
    broadcast_from :global, channel, topic, event, message
  end
  def broadcast(socket, event, message) do
    broadcast_from :global, socket.channel, socket.topic, event, message
  end

  def broadcast_from(socket = %Socket{}, event, message) do
    broadcast_from(socket.pid, socket.channel, socket.topic, event, message)
  end

  def broadcast_from(from, channel, topic, event, message) do
    Topic.create(namespaced(channel, topic))
    Topic.broadcast_from(from, namespaced(channel, topic), reply_json_frame(
      channel: channel,
      topic: topic,
      event: event,
      message: message
    ))
  end

  @doc """
  Sends Dict, JSON serializable message to socket
  """
  def reply(socket, event, message) do
    send socket.pid, reply_json_frame(
      channel: socket.channel,
      topic: socket.topic,
      event: event,
      message: message
    )
    {:ok, socket}
  end

  @doc """
  Converts Dict message into JSON text reply frame for Websocket Handler
  """
  def reply_json_frame(message) do
    {:reply, {:text, JSON.encode!(message)}}
  end

  defp namespaced(channel, topic), do: "#{channel}:#{topic}"
end
