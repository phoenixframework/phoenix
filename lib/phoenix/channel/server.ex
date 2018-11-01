defmodule Phoenix.Channel.Server do
  @moduledoc false
  use GenServer

  require Logger
  require Phoenix.Endpoint

  alias Phoenix.PubSub
  alias Phoenix.Socket
  alias Phoenix.Socket.{Broadcast, Message, Reply, PoolSupervisor}

  ## Transport API

  @doc """
  Starts a channel server.
  """
  def start_link(socket, payload, pid, ref) do
    GenServer.start_link(__MODULE__, {socket, payload, pid, ref})
  end

  @doc """
  Joins the channel in socket with authentication payload.
  """
  @spec join(Socket.t, module, Message.t, keyword) :: {:ok, map, pid, Socket.t} | {:error, map}
  def join(socket, channel, message, opts) do
    %{topic: topic, payload: payload, ref: join_ref} = message
    assigns = Keyword.get(opts, :assigns, %{})

    socket =
      %Socket{
        socket
        | topic: topic,
          channel: channel,
          join_ref: join_ref,
          assigns: Map.merge(socket.assigns, assigns),
          private: Map.merge(channel.__socket__(:private), socket.private)
      }

    instrument = %{params: payload, socket: socket}

    Phoenix.Endpoint.instrument socket, :phoenix_channel_join, instrument, fn ->
      ref = make_ref()
      key = {self(), ref}
      args = [socket, payload, self(), ref]

      case PoolSupervisor.start_child(socket.endpoint, socket.handler, key, args) do
        {:ok, :undefined} ->
          log_join socket, topic, fn -> "Replied #{topic} :error" end
          receive do: ({^ref, reply} -> {:error, reply})
        {:ok, pid} ->
          log_join socket, topic, fn -> "Replied #{topic} :ok" end
          receive do: ({^ref, reply} -> {:ok, reply, pid})
        {:error, reason} ->
          Logger.error fn -> Exception.format_exit(reason) end
          {:error, %{reason: "join crashed"}}
      end
    end
  end

  defp log_join(_, "phoenix" <> _, _func), do: :noop
  defp log_join(%{private: %{log_join: false}}, _topic, _func), do: :noop
  defp log_join(%{private: %{log_join: level}}, _topic, func), do: Logger.log(level, func)

  @doc """
  Gets the socket from the channel.
  """
  @spec socket(pid) :: Socket.t
  def socket(pid) do
    GenServer.call(pid, :socket)
  end

  @doc """
  Notifies the channels the clients closed.

  This event is synchronous as we want to guarantee
  proper termination of the channels.
  """
  @spec close([pid], timeout) :: :ok
  def close(pids, timeout \\ 5000)

  def close([], _timeout) do
    :ok
  end

  def close(pids, timeout) do
    # We need to guarantee that the channel has been closed
    # otherwise the link in the transport will trigger it to crash.
    pids_and_refs =
      for pid <- pids do
        ref = Process.monitor(pid)
        GenServer.cast(pid, :close)
        {pid, ref}
      end

    timeout_ref = make_ref()
    timer_ref = Process.send_after(self(), {:timeout, timeout_ref}, timeout)

    Enum.reduce(pids_and_refs, :infinity, fn {pid, ref}, timeout ->
      receive do
        {:DOWN, ^ref, _, _, _} -> timeout
        {:timeout, ^timeout_ref} -> kill(pid, ref)
      after
        timeout -> kill(pid, ref)
      end
    end)

    Process.cancel_timer(timer_ref)

    receive do
      {:timeout, ^timeout_ref} -> :ok
    after
      0 -> :ok
    end
  end

  defp kill(pid, ref) do
    Process.exit(pid, :kill)

    receive do
      {:DOWN, ^ref, _, _, _} -> 0
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
  def broadcast(_, topic, event, payload) do
    raise_invalid_message(topic, event, payload)
  end

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
  def broadcast!(_, topic, event, payload) do
    raise_invalid_message(topic, event, payload)
  end

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
  def broadcast_from(_, _from, topic, event, payload) do
    raise_invalid_message(topic, event, payload)
  end

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
  def broadcast_from!(_, _from, topic, event, payload) do
    raise_invalid_message(topic, event, payload)
  end

  @doc """
  Pushes a message with the given topic, event and payload
  to the given process.
  """
  def push(pid, topic, event, payload, serializer)
      when is_binary(topic) and is_binary(event) and is_map(payload) do
    message = %Message{topic: topic, event: event, payload: payload}
    send pid, serializer.encode!(message)
    :ok
  end
  def push(_, topic, event, payload, _) do
    raise_invalid_message(topic, event, payload)
  end

  @doc """
  Replies to a given ref to the transport process.
  """
  def reply(pid, join_ref, ref, topic, {status, payload}, serializer)
      when is_binary(topic) and is_map(payload) do
    reply = %Reply{topic: topic, join_ref: join_ref, ref: ref, status: status, payload: payload}
    send pid, serializer.encode!(reply)
    :ok
  end
  def reply(_, _, _, topic, {_status, payload}, _) do
    raise_invalid_message(topic, "phx_reply", payload)
  end

  @spec raise_invalid_message(topic :: term, event :: term, payload :: term) :: no_return()
  defp raise_invalid_message(topic, event, payload) do
    raise ArgumentError, """
    topic and event must be strings, message must be a map, got:

      topic: #{inspect topic}
      event: #{inspect event}
      payload: #{inspect payload}

    """
  end

  ## Callbacks

  @doc false
  def init({socket, auth_payload, parent, ref}) do
    _ = Process.monitor(socket.transport_pid)
    %{channel: channel, topic: topic} = socket
    socket = %{socket | channel_pid: self()}

    case channel.join(topic, auth_payload, socket) do
      {:ok, socket} ->
        init(socket, %{}, parent, ref)
      {:ok, reply, socket} ->
        init(socket, reply, parent, ref)
      {:error, reply} ->
        send(parent, {ref, reply})
        :ignore
      other ->
        raise """
        channel #{inspect socket.channel}.join/3 is expected to return one of:

            {:ok, Socket.t} |
            {:ok, reply :: map, Socket.t} |
            {:error, reply :: map}

        got #{inspect other}
        """
    end
  end

  defp init(socket, reply, parent, ref) do
    fastlane = {socket.transport_pid, socket.serializer, socket.channel.__intercepts__()}
    PubSub.subscribe(socket.pubsub_server, socket.topic, link: true, fastlane: fastlane)
    send(parent, {ref, reply})
    {:ok, %{socket | joined: true}}
  end

  @doc false
  def handle_call(:socket, _from, socket) do
    {:reply, socket, socket}
  end

  @doc false
  def handle_cast(:close, socket) do
    handle_result({:stop, {:shutdown, :closed}, socket}, :handle_cast)
  end

  @doc false
  def handle_info(%Message{topic: topic, event: "phx_leave", ref: ref}, %{topic: topic} = socket) do
    handle_in({:stop, {:shutdown, :left}, :ok, put_in(socket.ref, ref)})
  end

  def handle_info(%Message{topic: topic, event: event, payload: payload, ref: ref},
                  %{topic: topic} = socket) do
    Phoenix.Endpoint.instrument socket, :phoenix_channel_receive,
      %{ref: ref, event: event, params: payload, socket: socket}, fn ->
      event
      |> socket.channel.handle_in(payload, put_in(socket.ref, ref))
      |> handle_in()
    end
  end

  def handle_info(%Broadcast{topic: topic, event: event, payload: payload},
                  %Socket{topic: topic} = socket) do
    event
    |> socket.channel.handle_out(payload, socket)
    |> handle_result(:handle_out)
  end

  def handle_info({:DOWN, _, _, transport_pid, reason}, %{transport_pid: transport_pid} = socket) do
    handle_result({:stop, reason, socket}, :handle_info)
  end

  def handle_info(msg, %{channel: channel} = socket) do
    if function_exported?(channel, :handle_info, 2) do
      msg
      |> socket.channel.handle_info(socket)
      |> handle_result(:handle_info)
    else
      proc =
        case Process.info(self(), :registered_name) do
          {_, []}   -> self()
          {_, name} -> name
        end

      :error_logger.warning_msg('~p ~p received unexpected message in handle_info/2: ~p~n',
                                [__MODULE__, proc, msg])
      {:noreply, socket}
    end
  end

  @doc false
  def code_change(old, %{channel: channel} = socket, extra) do
    if function_exported?(channel, :code_change, 3) do
      channel.code_change(old, socket, extra)
    else
      {:ok, socket}
    end
  end

  @doc false
  def terminate(reason, %{channel: channel} = socket) do
    if function_exported?(channel, :terminate, 2) do
      channel.terminate(reason, socket)
    else
      :ok
    end
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

  defp handle_result({:stop, reason, socket}, _callback) do
    case reason do
      :normal -> notify_transport_of_graceful_exit(socket)
      :shutdown -> notify_transport_of_graceful_exit(socket)
      {:shutdown, _} -> notify_transport_of_graceful_exit(socket)
      _ -> :noop
    end
    {:stop, reason, socket}
  end

  defp handle_result({:noreply, socket}, _callback) do
    {:noreply, put_in(socket.ref, nil)}
  end

  defp handle_result({:noreply, socket, timeout_or_hibernate}, _callback) do
    {:noreply, put_in(socket.ref, nil), timeout_or_hibernate}
  end

  defp handle_result(result, :handle_in) do
    raise """
    Expected handle_in/3 to return one of:

        {:noreply, Socket.t} |
        {:noreply, Socket.t, timeout | :hibernate} |
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
    Expected #{callback} to return one of:

        {:noreply, Socket.t} |
        {:noreply, Socket.t, timeout | :hibernate} |
        {:stop, reason :: term, Socket.t} |

    got #{inspect result}
    """
  end

  defp notify_transport_of_graceful_exit(socket) do
    %{topic: topic, join_ref: ref, transport_pid: transport_pid} = socket
    close_msg = %Message{join_ref: ref, ref: ref, topic: topic, event: "phx_close", payload: %{}}
    send(transport_pid, {:graceful_exit, self(), close_msg})
    :ok
  end

  ## Handle in/replies

  defp handle_in({:reply, reply, %Socket{} = socket}) do
    handle_reply(socket, reply)
    {:noreply, put_in(socket.ref, nil)}
  end

  defp handle_in({:stop, reason, reply, socket}) do
    handle_reply(socket, reply)
    handle_result({:stop, reason, socket}, :handle_in)
  end

  defp handle_in(other) do
    handle_result(other, :handle_in)
  end

  defp handle_reply(socket, {status, payload}) when is_atom(status) and is_map(payload) do
    reply(socket.transport_pid, socket.join_ref, socket.ref, socket.topic, {status, payload},
          socket.serializer)
  end

  defp handle_reply(socket, status) when is_atom(status) do
    handle_reply(socket, {status, %{}})
  end

  defp handle_reply(_socket, reply) do
    raise """
    Channel replies from handle_in/3 are expected to be one of:

        status :: atom
        {status :: atom, response :: map}

    for example:

        {:reply, :ok, socket}
        {:reply, {:ok, %{}}, socket}
        {:stop, :shutdown, {:error, %{}}, socket}

    got #{inspect reply}
    """
  end
end
