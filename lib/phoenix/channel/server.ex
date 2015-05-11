defmodule Phoenix.Channel.Server do
  use GenServer

  alias Phoenix.PubSub
  alias Phoenix.Socket
  alias Phoenix.Socket.Broadcast
  alias Phoenix.Socket.Message
  alias Phoenix.Socket.Reply

  # TODO: Document me as the transport API.
  @moduledoc false

  ## Transport API

  @doc """
  Joins the channel in socket with authentication payload.
  """
  @spec join(Socket.t, map) :: {:ok, map, pid} | {:error, map}
  def join(socket, auth_payload) do
    ref = make_ref()

    case GenServer.start_link(__MODULE__, {socket, auth_payload, self(), ref}) do
      {:ok, pid} ->
        receive do: ({^ref, reply} -> {:ok, reply, pid})
      :ignore ->
        receive do: ({^ref, reply} -> {:error, reply})
      {:error, _} ->
        {:error, %{reason: "join crashed"}}
    end
  end

  @doc """
  Notifies the channel the client left.

  This event is async and a message is sent back to the
  transport as soon the leave command is processed (but
  before termination).
  """
  def leave(pid, ref) do
    GenServer.cast(pid, {:leave, ref})
  end

  @doc """
  Notifies the channel the client closed.

  This event is synchronous as we want to guarantee
  proper termination of the channel.
  """
  def close(pid, timeout \\ 5000) do
    # We need to guarantee that the channel has been closed
    # otherwise the link in the transport will trigger it to
    # crash.
    ref = Process.monitor(pid)
    GenServer.cast(pid, :close)
    receive do
      {:DOWN, ^ref, _, _, _} -> :ok
    after
      timeout ->
        Process.exit(pid, :kill)
        receive do
          {:DOWN, ^ref, _, _, _} -> :ok
        end
    end
  end

  ## Channel API

  @doc """
  Broadcasts on the given pubsub server with the given
  `topic`, `event` and `payload`.

  The message is encoded as `Phoenix.Socket.Broadcast`.
  """
  def broadcast(pubsub_server, topic, event, payload)
      when is_binary(topic) and is_binary(event) and is_map(payload) do
    PubSub.broadcast pubsub_server, topic, %Broadcast{
      topic: topic,
      event: event,
      payload: payload
    }
  end
  def broadcast(_, _, _, _, _), do: raise_invalid_message

  @doc """
  Broadcasts on the given pubsub server with the given
  `topic`, `event` and `payload`.

  Raises in case of crashes.
  """
  def broadcast!(pubsub_server, topic, event, payload)
      when is_binary(topic) and is_binary(event) and is_map(payload) do
    PubSub.broadcast! pubsub_server, topic, %Broadcast{
      topic: topic,
      event: event,
      payload: payload
    }
  end
  def broadcast!(_, _, _, _), do: raise_invalid_message

  @doc """
  Broadcasts on the given pubsub server with the given
  `from`, `topic`, `event` and `payload`.

  The message is encoded as `Phoenix.Socket.Broadcast`.
  """
  def broadcast_from(pubsub_server, from, topic, event, payload)
      when is_binary(topic) and is_binary(event) and is_map(payload) do
    PubSub.broadcast_from pubsub_server, from, topic, %Broadcast{
      topic: topic,
      event: event,
      payload: payload
    }
  end
  def broadcast_from(_, _, _, _, _), do: raise_invalid_message

  @doc """
  Broadcasts on the given pubsub server with the given
  `from`, `topic`, `event` and `payload`.

  Raises in case of crashes.
  """
  def broadcast_from!(pubsub_server, from, topic, event, payload)
      when is_binary(topic) and is_binary(event) and is_map(payload) do
    PubSub.broadcast_from! pubsub_server, from, topic, %Broadcast{
      topic: topic,
      event: event,
      payload: payload
    }
  end
  def broadcast_from!(_, _, _, _, _), do: raise_invalid_message

  @doc """
  Pushes a message with the given topic, event and payload
  to the given process.
  """
  def push(pid, topic, event, payload)
      when is_binary(topic) and is_binary(event) and is_map(payload) do
    send pid, %Message{
      topic: topic,
      event: event,
      payload: payload
    }
    :ok
  end
  def push(_, _, _, _), do: raise_invalid_message

  defp raise_invalid_message do
    raise ArgumentError, "topic and event must be strings, message must be a map"
  end

  ## Callbacks

  @doc false
  def init({socket, auth_payload, parent, ref}) do
    socket = %{socket | channel_pid: self()}

    case socket.channel.join(socket.topic, auth_payload, socket) do
      {:ok, socket} ->
        join(socket, %{}, parent, ref)
      {:ok, reply, socket} ->
        join(socket, reply, parent, ref)
      {:error, reply} ->
        send(parent, {ref, reply})
        :ignore
      other ->
        raise """
        Channel join is expected to return one of:

            {:ok, Socket.t} |
            {:ok, reply :: map, Socket.t} |
            {:error, reply :: map, Socket.t}

        got #{inspect other}
        """
    end
  end

  defp join(socket, reply, parent, ref) do
    PubSub.subscribe(socket.pubsub_server, self(), socket.topic, link: true)
    send(parent, {ref, reply})
    {:ok, %{socket | joined: true}}
  end

  @doc false
  def handle_cast(:close, socket) do
    handle_result({:stop, {:shutdown, :closed}, socket}, :handle_in)
  end

  def handle_cast({:leave, ref}, socket) do
    handle_result({:stop, {:shutdown, :left}, :ok, put_in(socket.ref, ref)}, :handle_in)
  end

  @doc false
  def handle_info(%Message{topic: topic, event: event, payload: payload, ref: ref},
                  %{topic: topic} = socket) do
    event
    |> socket.channel.handle_in(payload, put_in(socket.ref, ref))
    |> handle_result(:handle_in)
  end

  def handle_info(%Broadcast{topic: topic, event: event, payload: payload},
                  %{topic: topic} = socket) do
    event
    |> socket.channel.handle_out(payload, socket)
    |> handle_result(:handle_out)
  end

  def handle_info(msg, socket) do
    msg
    |> socket.channel.handle_info(socket)
    |> handle_result(:handle_info)
  end

  @doc false
  def terminate(reason, socket) do
    socket.channel.terminate(reason, socket)
  end

  ## Handle results

  defp handle_result({:reply, reply, %Socket{} = socket}, callback) do
    handle_reply(socket, reply, callback)
    {:noreply, socket}
  end

  defp handle_result({:stop, reason, reply, socket}, callback) do
    handle_reply(socket, reply, callback)
    {:stop, reason, socket}
  end

  defp handle_result({:stop, reason, socket}, _callback) do
    {:stop, reason, socket}
  end

  defp handle_result({:noreply, socket}, _callback) do
    {:noreply, socket}
  end

  defp handle_result(result, :handle_in) do
    raise """
    Expected `handle_in/3` to return one of:

        {:noreply, Socket.t} |
        {:reply, {status :: atom, response :: map}, Socket.t} |
        {:reply, status :: atom, Socket.t} |
        {:stop, reason :: term, Socket.t} |
        {:stop, reason :: term, {status :: atom, response :: map}, Socket.t} |
        {:stop, reason :: term, status :: atom, Socket.t}

    got #{inspect result}
    """
  end

  defp handle_result(result, callback) do
    raise """
    Expected `#{callback}` to return one of:

        {:noreply, Socket.t} |
        {:stop, reason :: term, Socket.t} |

    got #{inspect result}
    """
  end

  ## Handle replies

  defp handle_reply(socket, {status, payload}, :handle_in)
       when is_atom(status) and is_map(payload) do
    send socket.transport_pid, %Reply{status: status, topic: socket.topic,
                                      ref: socket.ref, payload: payload}
  end

  defp handle_reply(socket, status, :handle_in) when is_atom(status) do
    handle_reply(socket, {status, %{}}, :handle_in)
  end

  defp handle_reply(_socket, reply, :handle_in) do
    raise """
    Channel replies from `handle_in/3` are expected to be one of:

        status :: atom
        {status :: atom, response :: map}

    for example:

        {:reply, :ok, socket}
        {:reply, {:ok, %{}}, socket}
        {:stop, :shutdown, {:error, %{}}, socket}

    got #{inspect reply}
    """
  end

  defp handle_reply(_socket, _reply, _other) do
    raise """
    Channel replies can only be sent from a `handle_in/3` callback.
    Use `push/3` to send an out-of-band message down the socket
    """
  end
end
