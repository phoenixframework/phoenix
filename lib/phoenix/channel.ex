defmodule Phoenix.Channel do
  use Jazz
  alias Phoenix.Topic
  alias Phoenix.Socket
  alias Phoenix.Socket.Handler

  defmacro __using__(_options) do
    quote do
      import unquote(__MODULE__)

      def leave(socket, message), do: socket
      defoverridable leave: 2
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def event(socket, _event, _message), do: socket
    end
  end

  @doc """
  Subscribes socket to given channel topic
  Returns %Socket{}
  """
  def subscribe(socket, channel, topic) do
    if !Socket.authenticated?(socket, channel, topic) do
      Topic.subscribe(socket.pid, namespaced(channel, topic))
      Socket.add_channel(socket, channel, topic)
    else
      socket
    end
  end

  @doc """
  Unsubscribes socket to given channel topic
  Returns %Socket{}
  """
  def unsubscribe(socket, channel, topic) do
    Topic.unsubscribe(socket.pid, namespaced(channel, topic))
    Socket.delete_channel(socket, channel, topic)
  end

  @doc """
  Broadcast event, serializable as JSON to topic namedspaced by channel

  Examples

  iex> Channel.broadcast "rooms", "global", "new:message", id: 1, content: "hello"
  :ok
  iex> Channel.broadcast socket, "new:message", id: 1, content: "hello"
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
      message: Enum.into(message, %{})
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
      message: Enum.into(message, %{})
    )
    socket
  end

  @doc """
  Terminates socket connection, including all multiplexed channels
  """
  def terminate(socket), do: Handler.terminate(socket)

  @doc """
  Hibernates socket connection
  """
  def hibernate(socket), do: Handler.hibernate(socket)

  @doc """
  Converts Dict message into JSON text reply frame for Websocket Handler
  """
  def reply_json_frame(message) do
    {:reply, {:text, JSON.encode!(Enum.into(message, %{}))}}
  end

  defp namespaced(channel, topic), do: "#{channel}:#{topic}"
end
