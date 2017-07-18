defmodule Phoenix.Transports.LongPoll.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(options) do
    Supervisor.start_link(__MODULE__, [], options)
  end

  def init([]) do
    children = [
      worker(Phoenix.Transports.LongPoll.Server, [], restart: :temporary)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end

defmodule Phoenix.Transports.LongPoll.Server do
  @moduledoc false

  use GenServer

  alias Phoenix.PubSub
  alias Phoenix.Socket.{Transport, Broadcast}

  @doc """
  Starts the Server.

    * `socket` - The `Phoenix.Socket` struct returned from `connect/2`
      of the socket handler.
    * `window_ms` - The longpoll session timeout, in milliseconds

  If the server receives no message within `window_ms`, it terminates
  and clients are responsible for opening a new session.
  """
  def start_link(endpoint, handler, transport_name, transport,
                 serializer, params, window_ms, priv_topic) do
    GenServer.start_link(__MODULE__, [endpoint, handler, transport_name, transport,
                                      serializer, params, window_ms, priv_topic])
  end

  ## Callbacks

  def init([endpoint, handler, transport_name, transport,
            serializer, params, window_ms, priv_topic]) do
    Process.flag(:trap_exit, true)

    case Transport.connect(endpoint, handler, transport_name, transport, serializer, params) do
      {:ok, socket} ->
        state = %{buffer: [],
                  socket: socket,
                  channels: %{},
                  channels_inverse: %{},
                  window_ms: trunc(window_ms * 1.5),
                  pubsub_server: socket.endpoint.__pubsub_server__(),
                  priv_topic: priv_topic,
                  last_client_poll: now_ms(),
                  serializer: socket.serializer,
                  client_ref: nil}

        if socket.id, do: PubSub.subscribe(state.pubsub_server, socket.id, link: true)
        :ok = PubSub.subscribe(state.pubsub_server, priv_topic, link: true)

        schedule_inactive_shutdown(state.window_ms)

        {:ok, state}
      :error ->
        :ignore
    end
  end

  def handle_call(:stop, _from, state), do: {:stop, :shutdown, :ok, state}

  # Handle client dispatches
  def handle_info({:dispatch, client_ref, msg, ref}, state) do
    msg
    |> Transport.dispatch(state.channels, state.socket)
    |> case do
      {:joined, channel_pid, reply_msg} ->
        broadcast_from!(state, client_ref, {:dispatch, ref})
        new_state = %{state | channels: Map.put(state.channels, msg.topic, channel_pid),
                              channels_inverse: Map.put(state.channels_inverse, channel_pid, {msg.topic, msg.ref})}
        publish_reply(reply_msg, new_state)

      {:reply, reply_msg} ->
        broadcast_from!(state, client_ref, {:dispatch, ref})
        publish_reply(reply_msg, state)

      :noreply ->
        broadcast_from!(state, client_ref, {:dispatch, ref})
        {:noreply, state}

      {:error, reason, error_reply_msg} ->
        broadcast_from!(state, client_ref, {:error, reason, ref})
        publish_reply(error_reply_msg, state)
    end
  end

  # Detects disconnect broadcasts and shuts down
  def handle_info(%Broadcast{event: "disconnect"}, state) do
    {:stop, {:shutdown, :disconnected}, state}
  end

  def handle_info({:EXIT, channel_pid, reason}, state) do
    case Map.get(state.channels_inverse, channel_pid) do
      nil ->
        {:stop, {:shutdown, :pubsub_server_terminated}, state}
      {topic, join_ref} ->
        new_state = delete(state, topic, channel_pid)
        msg = Transport.on_exit_message(topic, join_ref, reason)

        publish_reply(msg, new_state)
    end
  end

  def handle_info({:graceful_exit, channel_pid, %Phoenix.Socket.Message{} = msg}, state) do
    new_state = delete(state, msg.topic, channel_pid)
    publish_reply(msg, new_state)
  end

  def handle_info({:subscribe, client_ref, ref}, state) do
    broadcast_from!(state, client_ref, {:subscribe, ref})
    {:noreply, state}
  end

  def handle_info({:flush, client_ref, ref}, state) do
    case state.buffer do
      [] ->
        {:noreply, %{state | client_ref: {client_ref, ref}, last_client_poll: now_ms()}}
      buffer ->
        broadcast_from!(state, client_ref, {:messages, Enum.reverse(buffer), ref})
        {:noreply, %{state | client_ref: nil, last_client_poll: now_ms(), buffer: []}}
    end
  end

  def handle_info(:shutdown_if_inactive, state) do
    if now_ms() - state.last_client_poll > state.window_ms do
      {:stop, {:shutdown, :inactive}, state}
    else
      schedule_inactive_shutdown(state.window_ms)
      {:noreply, state}
    end
  end

  def handle_info({:socket_push, :text, encoded}, state) do
    notify_client_now_available(state)
    {:noreply, %{state | buffer: [encoded | state.buffer]}}
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp broadcast_from!(state, client_ref, msg) when is_binary(client_ref),
    do: PubSub.broadcast_from!(state.pubsub_server, self(), client_ref, msg)
  defp broadcast_from!(_state, client_ref, msg) when is_pid(client_ref),
    do: send(client_ref, msg)

  defp publish_reply(msg, state) do
    notify_client_now_available(state)
    {:socket_push, :text, encoded} = state.serializer.encode!(msg)

    {:noreply, %{state | buffer: [encoded | state.buffer]}}
  end

  defp notify_client_now_available(state) do
    case state.client_ref do
      {client_ref, ref} ->
        broadcast_from!(state, client_ref, {:now_available, ref})
      nil ->
        :ok
    end
  end

  defp now_ms, do: System.system_time(:milliseconds)

  defp schedule_inactive_shutdown(window_ms) do
    Process.send_after(self(), :shutdown_if_inactive, window_ms)
  end

  defp delete(state, topic, channel_pid) do
    case Map.fetch(state.channels, topic) do
      {:ok, ^channel_pid} ->
        %{state | channels: Map.delete(state.channels, topic),
                  channels_inverse: Map.delete(state.channels_inverse, channel_pid)}
      {:ok, _newer_pid} ->
        %{state | channels_inverse: Map.delete(state.channels_inverse, channel_pid)}
    end
  end
end
