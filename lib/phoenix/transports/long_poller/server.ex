defmodule Phoenix.Transports.LongPoller.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    children = [
      worker(Phoenix.Transports.LongPoller.Server, [], restart: :transient)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end

defmodule Phoenix.Transports.LongPoller.Server do
  use GenServer

  @moduledoc false

  alias Phoenix.Channel.Transport
  alias Phoenix.Transports.LongPoller
  alias Phoenix.PubSub
  alias Phoenix.Socket.Message
  alias Phoenix.Socket.Reply
  alias Phoenix.Socket.Broadcast

  @doc """
  Starts the Server.

    * `socket_handler` - The socket handler module, ie. `MyApp.UserSocket`
    * `socket` - The `%Phoenix.Socket{}` struct returend from `connect/2` of the
                 socket handler.
    * `window_ms` - The longpoll session timeout, in milliseconds

  If the server receives no message within `window_ms`, it terminates and
  clients are responsible for opening a new session.
  """
  def start_link(socket_handler, socket, window_ms, priv_topic, endpoint) do
    GenServer.start_link(__MODULE__, [socket_handler, socket, window_ms, priv_topic, endpoint])
  end

  @doc false
  def init([socket_handler, socket, window_ms, priv_topic, endpoint]) do
    Process.flag(:trap_exit, true)

    state = %{buffer: [],
              socket_handler: socket_handler,
              socket: socket,
              sockets: HashDict.new,
              sockets_inverse: HashDict.new,
              window_ms: trunc(window_ms * 1.5),
              endpoint: endpoint,
              pubsub_server: Process.whereis(endpoint.__pubsub_server__()),
              priv_topic: priv_topic,
              last_client_poll: now_ms(),
              client_ref: nil}

    if socket.id, do: endpoint.subscribe(self, socket.id, link: true)
    :ok = PubSub.subscribe(state.pubsub_server, self, state.priv_topic, link: true)
    :timer.send_interval(state.window_ms, :shutdown_if_inactive)

    {:ok, state}
  end

  @doc """
  Stops the server
  """
  def handle_call(:stop, _from, state), do: {:stop, :shutdown, :ok, state}

  @doc """
  Dispatches client message back through Transport layer.
  """
  def handle_info({:dispatch, msg, ref}, state) do
    msg
    |> Transport.dispatch(state.sockets, self, state.socket_handler, state.socket, state.endpoint, LongPoller)
    |> case do
      {:ok, socket_pid} ->
        :ok = broadcast_from(state, {:ok, :dispatch, ref})

        new_state = %{state | sockets: HashDict.put(state.sockets, msg.topic, socket_pid),
                              sockets_inverse: HashDict.put(state.sockets_inverse, socket_pid, msg.topic)}
        {:noreply, new_state}
      :ok ->
        :ok = broadcast_from(state, {:ok, :dispatch, ref})
        {:noreply, state}
      {:error, reason} ->
        :ok = broadcast_from(state, {:error, :dispatch, reason, ref})
        {:noreply, state}
    end
  end

  @doc """
  Forwards replied/broadcasted message from Channels back to client.
  """
  def handle_info(%Message{} = msg, state) do
    publish_reply(msg, state)
  end

  def handle_info(%Reply{} = reply, state) do
    %{topic: topic, status: status, payload: payload, ref: ref} = reply

    message = %Message{event: "phx_reply", topic: topic, ref: ref,
                       payload: %{status: status, response: payload}}

    publish_reply(message, state)
  end

  @doc """
  Detects disconnect broadcasts and shuts down
  """
  def handle_info(%Broadcast{event: "disconnect"}, state) do
    {:stop, {:shutdown, :disconnected}, state}
  end

  @doc """
  Crash if pubsub adapter goes down
  """
  def handle_info({:EXIT, pub_pid, :shutdown}, %{pubsub_server: pub_pid} = state) do
    {:stop, :pubsub_server_terminated, state}
  end

  @doc """
  Trap channel process exits and notify client of close or error events

  `:normal` exits and shutdowns indicate the channel shutdown gracefully from
   return. Any other exit reason is treated as an error.
  """
  def handle_info({:EXIT, socket_pid, reason}, state) do
    case HashDict.get(state.sockets_inverse, socket_pid) do
      nil   -> {:noreply, state}
      topic ->
        new_state = %{state | sockets: HashDict.delete(state.sockets, topic),
                              sockets_inverse: HashDict.delete(state.sockets_inverse, socket_pid)}
        case reason do
          :normal ->
            publish_reply(Transport.chan_close_message(topic), new_state)
          {:shutdown, _} ->
            publish_reply(Transport.chan_close_message(topic), new_state)
          _other ->
            publish_reply(Transport.chan_error_message(topic), new_state)
        end
    end
  end

  def handle_info({:subscribe, ref}, state) do
    :ok = broadcast_from(state, {:ok, :subscribe, ref})

    {:noreply, state}
  end

  def handle_info({:flush, ref}, state) do
    if Enum.any?(state.buffer) do
      :ok = broadcast_from(state, {:messages, Enum.reverse(state.buffer), ref})
    end
    {:noreply, %{state | client_ref: ref, last_client_poll: now_ms()}}
  end

  # TODO: Messages need unique ids so we can properly ack them
  @doc """
  Handles acknowledged messages from client and removes from buffer.
  `:ack` calls to the server also represent the client listener
  closing for repoll.
  """
  def handle_info({:ack, msg_count, ref}, state) do
    buffer = Enum.drop(state.buffer, -msg_count)
    :ok = broadcast_from(state, {:ok, :ack, ref})

    {:noreply, %{state | buffer: buffer}}
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
    buffer = [msg | state.buffer]
    if state.client_ref do
      :ok = broadcast_from(state, {:messages, Enum.reverse(buffer), state.client_ref})
    end

    {:noreply, %{state | buffer: buffer}}
  end

  defp time_to_ms({mega, sec, micro}),
    do: div(((((mega * 1000000) + sec) * 1000000) + micro), 1000)
  defp now_ms, do: :os.timestamp() |> time_to_ms()
end
