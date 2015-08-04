defmodule Phoenix.Transports.LongPoll.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    children = [
      worker(Phoenix.Transports.LongPoll.Server, [], restart: :transient)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end

defmodule Phoenix.Transports.LongPoll.Server do
  @moduledoc false

  use GenServer

  alias Phoenix.Socket.Transport
  alias Phoenix.PubSub
  alias Phoenix.Socket.Broadcast
  alias Phoenix.Socket.Message

  @doc """
  Starts the Server.

    * `socket` - The `Phoenix.Socket` struct returend from `connect/2`
      of the socket handler.
    * `window_ms` - The longpoll session timeout, in milliseconds

  If the server receives no message within `window_ms`, it terminates
  and clients are responsible for opening a new session.
  """
  def start_link(socket, window_ms, priv_topic) do
    GenServer.start_link(__MODULE__, [socket, window_ms, priv_topic])
  end

  ## Callbacks

  def init([socket, window_ms, priv_topic]) do
    Process.flag(:trap_exit, true)

    state = %{buffer: [],
              socket: %{socket | transport_pid: self()},
              channels: HashDict.new,
              channels_inverse: HashDict.new,
              window_ms: trunc(window_ms * 1.5),
              pubsub_server: socket.endpoint.__pubsub_server__(),
              priv_topic: priv_topic,
              last_client_poll: now_ms(),
              client_ref: nil}

    if socket.id, do: socket.endpoint.subscribe(self, socket.id, link: true)
    :ok = PubSub.subscribe(state.pubsub_server, self, state.priv_topic, link: true)
    :timer.send_interval(state.window_ms, :shutdown_if_inactive)

    {:ok, state}
  end

  def handle_call(:stop, _from, state), do: {:stop, :shutdown, :ok, state}

  # Handle client dispatches
  def handle_info({:dispatch, msg, ref}, state) do
    msg
    |> Transport.dispatch(state.channels, state.socket)
    |> case do
      {:joined, channel_pid, reply_msg} ->
        :ok = broadcast_from(state, {:dispatch, ref})
        new_state = %{state | channels: HashDict.put(state.channels, msg.topic, channel_pid),
                              channels_inverse: HashDict.put(state.channels_inverse, channel_pid, msg.topic)}
        publish_reply(reply_msg, new_state)

      {:reply, reply_msg} ->
        :ok = broadcast_from(state, {:dispatch, ref})
        publish_reply(reply_msg, state)

      :noreply ->
        :ok = broadcast_from(state, {:dispatch, ref})
        {:noreply, state}

      {:error, reason, error_reply_msg} ->
        :ok = broadcast_from(state, {:error, reason, ref})
        publish_reply(error_reply_msg, state)
    end
  end

  # Forwards replied/broadcasted message from Channels back to client.
  def handle_info(%Message{} = msg, state) do
    publish_encoded_reply(msg, state)
  end

  # Detects disconnect broadcasts and shuts down
  def handle_info(%Broadcast{event: "disconnect"}, state) do
    {:stop, {:shutdown, :disconnected}, state}
  end

  # Crash if pubsub adapter goes down
  def handle_info({:EXIT, pub_pid, :shutdown}, %{pubsub_server: pub_pid} = state) do
    {:stop, {:shutdown, :pubsub_server_terminated}, state}
  end

  # Trap channel process exits and notify client of close or error events
  #
  # Normal exits and shutdowns indicate the channel shutdown gracefully
  # from return. Any other exit reason is treated as an error.
  def handle_info({:EXIT, channel_pid, reason}, state) do
    case HashDict.get(state.channels_inverse, channel_pid) do
      nil   -> {:noreply, state}
      topic ->
        new_state = %{state | channels: HashDict.delete(state.channels, topic),
                              channels_inverse: HashDict.delete(state.channels_inverse, channel_pid)}
        publish_reply(Transport.on_exit_message(topic, reason), new_state)
    end
  end

  def handle_info({:subscribe, ref}, state) do
    :ok = broadcast_from(state, {:subscribe, ref})
    {:noreply, state}
  end

  def handle_info({:flush, ref}, state) do
    case state.buffer do
      [] ->
        {:noreply, %{state | client_ref: ref, last_client_poll: now_ms()}}
      buffer ->
        :ok = broadcast_from(state, {:messages, Enum.reverse(buffer), ref})
        {:noreply, %{state | client_ref: nil, last_client_poll: now_ms(), buffer: []}}
    end
  end

  def handle_info(:shutdown_if_inactive, state) do
    if now_ms() - state.last_client_poll > state.window_ms do
      {:stop, {:shutdown, :inactive}, state}
    else
      {:noreply, state}
    end
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp broadcast_from(state, msg) do
    PubSub.broadcast_from(state.pubsub_server, self, state.priv_topic, msg)
  end

  defp publish_reply(msg, state) do
    publish_encoded_reply(state.socket.serializer.encode!(msg), state)
  end
  defp publish_encoded_reply(msg, state) do
    if ref = state.client_ref do
      :ok = broadcast_from(state, {:now_available, ref})
    end

    {:noreply, %{state | buffer: [msg | state.buffer]}}
  end

  defp time_to_ms({mega, sec, micro}),
    do: div(((((mega * 1000000) + sec) * 1000000) + micro), 1000)
  defp now_ms, do: :os.timestamp() |> time_to_ms()
end
