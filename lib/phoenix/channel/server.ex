defmodule Phoenix.Channel.Server do
  use GenServer
  require Logger
  require Phoenix.Endpoint
  alias Phoenix.PubSub
  alias Phoenix.Socket
  alias Phoenix.Socket.{Broadcast, Message, Reply}

  @moduledoc false

  ## Transport API

  @doc """
  Joins the channel in socket with authentication payload.
  """
  @spec join(Socket.t, map) :: {:ok, map, pid} | {:error, map}
  def join(socket, auth_payload) do
    Phoenix.Endpoint.instrument socket, :phoenix_channel_join,
      %{params: auth_payload, socket: socket}, fn ->
      ref = make_ref()

      case GenServer.start_link(__MODULE__, {socket, auth_payload, self(), ref}) do
        {:ok, pid} ->
          receive do: ({^ref, reply} -> {:ok, reply, pid})
        :ignore ->
          receive do: ({^ref, reply} -> {:error, reply})
        {:error, reason} ->
          Logger.error fn -> Exception.format_exit(reason) end
          {:error, %{reason: "join crashed"}}
      end
    end
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

  @doc """
  Gets the socket from the channel.
  """
  def socket(pid) do
    GenServer.call(pid, :socket)
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
  def broadcast(_, _, _, _), do: raise_invalid_message()

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
  def broadcast!(_, _, _, _), do: raise_invalid_message()

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
  def broadcast_from(_, _, _, _, _), do: raise_invalid_message()

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
  def broadcast_from!(_, _, _, _, _), do: raise_invalid_message()

  @doc """
  Pushes a message with the given topic, event and payload
  to the given process.
  """
  def push(pid, topic, event, payload, serializer)
      when is_binary(topic) and is_binary(event) and is_map(payload) do

    encoded_msg = serializer.encode!(%Message{topic: topic,
                                              event: event,
                                              payload: payload})
    send pid, encoded_msg
    :ok
  end
  def push(_, _, _, _, _), do: raise_invalid_message()

  @doc """
  Replies to a given ref to the transport process.
  """
  def reply(pid, ref, topic, {status, payload}, serializer)
      when is_binary(topic) and is_map(payload) do

    send pid, serializer.encode!(
      %Reply{topic: topic, ref: ref, status: status, payload: payload}
    )
    :ok
  end
  def reply(_, _, _, _, _), do: raise_invalid_message()


  @spec raise_invalid_message() :: no_return()
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
            {:error, reply :: map}

        got #{inspect other}
        """
    end
  end

  @doc false
  def code_change(old, socket, extra) do
    socket.channel.code_change(old, socket, extra)
  end

  defp join(socket, reply, parent, ref) do
    PubSub.subscribe(socket.pubsub_server, socket.topic,
      link: true,
      fastlane: {socket.transport_pid,
                 socket.serializer,
                 socket.channel.__intercepts__()})

    send(parent, {ref, reply})
    {:ok, %{socket | joined: true}}
  end

  @doc false
  def handle_call(:socket, _from, socket) do
    {:reply, socket, socket}
  end

  @doc false
  def handle_cast(:close, socket) do
    handle_result({:stop, {:shutdown, :closed}, socket}, :handle_in)
  end

  def handle_info(%Message{topic: topic, event: "phx_leave", ref: ref}, %{topic: topic} = socket) do
    handle_result({:stop, {:shutdown, :left}, :ok, put_in(socket.ref, ref)}, :handle_in)
  end

  def handle_info(%Message{topic: topic, event: event, payload: payload, ref: ref},
                  %{topic: topic} = socket) do
    Phoenix.Endpoint.instrument socket, :phoenix_channel_receive,
      %{ref: ref, event: event, params: payload, socket: socket}, fn ->
      event
      |> socket.channel.handle_in(payload, put_in(socket.ref, ref))
      |> handle_result(:handle_in)
    end
  end

  def handle_info(%Broadcast{topic: topic, event: event, payload: payload},
                  %Socket{topic: topic} = socket) do
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

  @doc false
  def fastlane(subscribers, from, %Broadcast{event: event} = msg) do
    Enum.reduce(subscribers, %{}, fn
      {pid, _fastlanes}, cache when pid == from ->
        cache

      {pid, nil}, cache ->
        send(pid, msg)
        cache

      {pid, {fastlane_pid, serializer, event_intercepts}}, cache ->
        if event in event_intercepts do
          send(pid, msg)
          cache
        else
          case Map.fetch(cache, serializer) do
            {:ok, encoded_msg} ->
              send(fastlane_pid, encoded_msg)
              cache
            :error ->
              encoded_msg = serializer.fastlane!(msg)
              send(fastlane_pid, encoded_msg)
              Map.put(cache, serializer, encoded_msg)
          end
        end
    end)
  end

  def fastlane(subscribers, from, msg) do
    Enum.each(subscribers, fn
      {pid, _} when pid == from -> :noop
      {pid, _} -> send(pid, msg)
    end)
  end

  ## Handle results

  defp handle_result({:reply, reply, %Socket{} = socket}, callback) do
    handle_reply(socket, reply, callback)
    {:noreply, put_in(socket.ref, nil)}
  end

  defp handle_result({:stop, reason, reply, socket}, callback) do
    handle_reply(socket, reply, callback)
    {:stop, reason, socket}
  end

  defp handle_result({:stop, reason, socket}, _callback) do
    {:stop, reason, socket}
  end

  defp handle_result({:noreply, socket}, _callback) do
    {:noreply, put_in(socket.ref, nil)}
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

    reply(socket.transport_pid, socket.ref, socket.topic, {status, payload},
          socket.serializer)
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
