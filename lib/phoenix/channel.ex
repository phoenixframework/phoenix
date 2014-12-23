defmodule Phoenix.Channel do
  use Behaviour
  alias Phoenix.PubSub
  alias Phoenix.Socket
  alias Phoenix.Socket.Message

  defcallback join(Socket.t, channel :: binary, auth_msg :: map) :: {:ok, Socket.t} |
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
  Subscribes socket to given channel
  Returns `%Phoenix.Socket{}`
  """
  def subscribe(pid, channel) when is_pid(pid) do
    PubSub.subscribe(pid, channel)
  end
  def subscribe(socket, channel) do
    if !Socket.authorized?(socket, channel) do
      PubSub.subscribe(socket.pid, channel)
      Socket.authorize(socket, channel)
    else
      socket
    end
  end

  @doc """
  Unsubscribes socket from given channel
  Returns `%Phoenix.Socket{}`
  """
  def unsubscribe(pid, channel) when is_pid(pid) do
    PubSub.unsubscribe(pid, channel)
  end
  def unsubscribe(socket, channel) do
    PubSub.unsubscribe(socket.pid, channel)
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
  def broadcast(channel, event, message) when is_binary(channel) do
    broadcast_from :global, channel, event, message
  end

  def broadcast(socket = %Socket{}, event, message) do
    broadcast_from :global, socket.channel, event, message
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
    broadcast_from(socket.pid, socket.channel, event, message)
  end
  def broadcast_from(from, channel, event, message) when is_map(message) do
    PubSub.create(channel)
    PubSub.broadcast_from from, channel, {:broadcast, %Message{
      channel: channel,
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
      channel: socket.channel,
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
