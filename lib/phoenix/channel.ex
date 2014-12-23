defmodule Phoenix.Channel do
  use Behaviour
  alias Phoenix.PubSub
  alias Phoenix.Socket
  alias Phoenix.Socket.Message

  defcallback join(Socket.t, topic :: binary, auth_msg :: map) :: {:ok, Socket.t} |
                                                                  {:error, Socket.t, reason :: term}

  defmacro __using__(_options) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)
      import Phoenix.Socket

      def leave(socket, message), do: socket
      def outgoing(socket, event, message) do
        reply(socket, event, message)
        socket
      end
      defoverridable leave: 2, outgoing: 3
    end
  end


  # TODO: Move this to pubsub
  @doc """
  Subscribes socket to given topic
  Returns `%Phoenix.Socket{}`
  """
  def subscribe(pid, topic) when is_pid(pid) do
    PubSub.subscribe(pid, topic)
  end
  def subscribe(socket, topic) do
    if !Socket.authorized?(socket, topic) do
      PubSub.subscribe(socket.pid, topic)
      Socket.authorize(socket, topic)
    else
      socket
    end
  end

  @doc """
  Unsubscribes socket from given topic
  Returns `%Phoenix.Socket{}`
  """
  def unsubscribe(pid, topic) when is_pid(pid) do
    PubSub.unsubscribe(pid, topic)
  end
  def unsubscribe(socket, topic) do
    PubSub.unsubscribe(socket.pid, topic)
    Socket.deauthorize(socket)
  end

  @doc """
  Broadcast event, serializable as JSON to channel

  ## Examples

      iex> Channel.broadcast "rooms:global", "new:message", %{id: 1, content: "hello"}
      :ok
      iex> Channel.broadcast socket, "new:message", %{id: 1, content: "hello"}
      :ok

  """
  def broadcast(topic, event, message) when is_binary(topic) do
    broadcast_from :global, topic, event, message
  end

  def broadcast(socket = %Socket{}, event, message) do
    broadcast_from :global, socket.topic, event, message
  end

  @doc """
  Broadcast event from pid, serializable as JSON to channel
  The broadcasting socket `from`, does not receive the published message.
  The event's message must be a map serializable as JSON.

  ## Examples

      iex> Channel.broadcast_from self, "rooms:global", "new:message", %{id: 1, content: "hello"}
      :ok

  """
  def broadcast_from(socket = %Socket{}, event, message) do
    broadcast_from(socket.pid, socket.topic, event, message)
  end
  def broadcast_from(from, topic, event, message) when is_map(message) do
    PubSub.create(topic)
    PubSub.broadcast_from from, topic, {:broadcast, %Message{
      topic: topic,
      event: event,
      message: message
    }}
  end
  def broadcast_from(_, _, _, _), do: raise_invalid_message

  @doc """
  Sends Dict, JSON serializable message to socket
  """
  def reply(socket, event, message) when is_map(message) do
    send socket.pid, %Message{
      topic: socket.topic,
      event: event,
      message: message
    }
    socket
  end
  def reply(_, _, _), do: raise_invalid_message

  @doc """
  Terminates socket connection, including all multiplexed channels
  """
  def terminate(socket), do: send(socket.pid, :shutdown)

  @doc """
  Hibernates socket connection
  """
  def hibernate(socket), do: send(socket.pid, :hibernate)

  defp raise_invalid_message, do: raise "Message argument must be a map"
end
