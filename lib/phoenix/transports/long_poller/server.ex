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

  alias Phoenix.Socket.Message
  alias Phoenix.Channel.Transport
  alias Phoenix.Transports.LongPoller

  @doc """
  Starts the Server

    * `router` - The router module, ie. `MyApp.Router`
    * `window_ms` - The longpoll session timeout, in milliseconds

  If the server receives no message within `window_ms`, it terminates and
  clients are responsible for opening a new session.
  """
  def start_link(router, window_ms, priv_topic) do
    GenServer.start_link(__MODULE__, [router, window_ms, priv_topic])
  end

  @doc false
  def init([router, window_ms, priv_topic]) do
    Process.flag(:trap_exit, true)

    state = %{buffer: [],
              router: router,
              sockets: HashDict.new,
              window_ms: window_ms * 2,
              pubsub_server: router.pubsub_server(),
              priv_topic: priv_topic}

    :ok = Phoenix.PubSub.subscribe(state.pubsub_server, self, state.priv_topic)
    {:ok, state, state.window_ms}
  end

  @doc """
  Stops the server
  """
  def handle_call(:stop, _from, state), do: {:stop, :shutdown, :ok, state}

  @doc """
  Dispatches client `%Phoenix.Socket.Messages{}` back through Transport layer
  """
  def handle_info({:dispatch, message}, state) do
    message
    |> Transport.dispatch(state.sockets, self, state.router, LongPoller)
    |> case do
      {:ok, sockets} ->
        :ok = broadcast_from(state, {:ok, :dispatch})
        {:noreply, %{state | sockets: sockets}, state.window_ms}
      {:error, reason, sockets} ->
        :ok = broadcast_from(state, {:error, :dispatch, reason})
        {:noreply, %{state | sockets: sockets}, state.window_ms}
    end
  end

  @doc """
  Forwards replied/broadcasted `%Phoenix.Socket.Message{}`s from Channels back to client
  """
  def handle_info({:socket_reply, message = %Message{}}, state) do
    buffer = [message | state.buffer]
    :ok = broadcast_from(state, {:messages, Enum.reverse(buffer)})
    {:noreply, %{state | buffer: buffer}, state.window_ms}
  end
  def handle_info({:socket_broadcast, message = %Message{}}, %{sockets: sockets} = state) do
    sockets = case Transport.dispatch_broadcast(sockets, message) do
      {:ok, socks} -> socks
      {:error, _reason, socks} -> socks
    end

    {:noreply, %{state | sockets: sockets}, state.window_ms}
  end

  def handle_info(:ping, state) do
    :ok = broadcast_from(state, :pong)
    {:noreply, state, state.window_ms}
  end

  def handle_info(:flush, state) do
    if Enum.any?(state.buffer) do
      :ok = broadcast_from(state, {:messages, Enum.reverse(state.buffer)})
    end
    {:noreply, state, state.window_ms}
  end

  # TODO: %Messages{}'s need unique ids so we can properly ack them
  @doc """
  Handles acknowledged messages from client and removes from buffer.
  `:ack` calls to the server also represent the client listener
  closing for repoll.
  """
  def handle_info({:ack, messages}, state) do
    buffer = state.buffer -- messages
    :ok = broadcast_from(state, {:ok, :ack})

    {:noreply, %{state | buffer: buffer}, state.window_ms}
  end


  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  @doc """
  Handles forwarding arbitrary Elixir messages back to listening client
  """
  def terminate(reason, state) do
    :ok = Transport.dispatch_leave(state.sockets, reason)
    :ok
  end

  defp broadcast_from(state, msg) do
    Phoenix.PubSub.broadcast_from(state.pubsub_server, self, state.priv_topic, msg)
  end
end
