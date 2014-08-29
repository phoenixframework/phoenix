defmodule Phoenix.Channel do
  use Behaviour
  alias Phoenix.Topic
  alias Phoenix.Socket
  alias Phoenix.Socket.Message
  alias Phoenix.Socket.Handler

  defcallback join(Socket.t, topic :: binary, auth_msg :: map) :: {:ok, Socket.t} |
                                                                  {:error, Socket.t, reason :: term}

  defmacro __using__(_options) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)

      def leave(socket, message), do: socket
      defoverridable leave: 2
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
  Unsubscribes socket from given channel topic
  Returns %Socket{}
  """
  def unsubscribe(socket, channel, topic) do
    Topic.unsubscribe(socket.pid, namespaced(channel, topic))
    Socket.delete_channel(socket, channel, topic)
  end

  @doc """
  Broadcast event, serializable as JSON to topic namedspaced by channel

  ## Examples

      iex> Channel.broadcast "rooms", "global", "new:message", %{id: 1, content: "hello"}
      :ok
      iex> Channel.broadcast socket, "new:message", %{id: 1, content: "hello"}
      :ok

  """
  def broadcast(channel, topic, event, message) when is_binary(channel) and is_map(message) do
    broadcast_from :global, channel, topic, event, message
  end
  def broadcast(_, _, _, _), do: invalid_message_arg

  def broadcast(socket, event, message) do
    broadcast_from :global, socket.channel, socket.topic, event, message
  end

  def broadcast_from(socket = %Socket{}, event, message) when is_map(message) do
    broadcast_from(socket.pid, socket.channel, socket.topic, event, message)
  end

  def broadcast_from(_, _, _), do: invalid_message_arg

  @doc """
  Broadcast event from pid, serializable as JSON to topic namedspaced by channel
  The broadcasting socket `from`, does not receive the published message.

  ## Examples

      iex> Channel.broadcast_from self, "rooms", "global", "new:message", %{id: 1, content: "hello"}
      :ok

  """
  def broadcast_from(from, channel, topic, event, message) when is_map(message) do
    Topic.create(namespaced(channel, topic))
    Topic.broadcast_from from, namespaced(channel, topic), %Message{
      channel: channel,
      topic: topic,
      event: event,
      message: message
    }
  end

  def broadcast_from(_, _, _, _, _), do: invalid_message_arg

  @doc """
  Sends Dict, JSON serializable message to socket
  """
  def reply(socket, event, message) when is_map(message) do
    send socket.pid, %Message{
      channel: socket.channel,
      topic: socket.topic,
      event: event,
      message: message
    }
    socket
  end

  def reply(_, _, _), do: invalid_message_arg

  @doc """
  Terminates socket connection, including all multiplexed channels
  """
  def terminate(socket), do: Handler.terminate(socket)

  @doc """
  Hibernates socket connection
  """
  def hibernate(socket), do: Handler.hibernate(socket)

  defp namespaced(channel, topic), do: "#{channel}:#{topic}"
  defp invalid_message_arg do
    raise "Message argument must be of type Map"
  end
end
