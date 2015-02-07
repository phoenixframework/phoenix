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
  def start_link(router, window_ms, priv_topic, pubsub_server) do
    GenServer.start_link(__MODULE__, [router, window_ms, priv_topic, pubsub_server])
  end

  @doc false
  def init([router, window_ms, priv_topic, pubsub_server]) do
    Process.flag(:trap_exit, true)

    state = %{buffer: [],
              router: router,
              sockets: HashDict.new,
              window_ms: window_ms * 2,
              pubsub_server: pubsub_server,
              priv_topic: priv_topic,
              client_ref: nil}

    :ok = Phoenix.PubSub.subscribe(state.pubsub_server, self, state.priv_topic, link: true)
    {:ok, state, state.window_ms}
  end

  @doc """
  Stops the server
  """
  def handle_call(:stop, _from, state), do: {:stop, :shutdown, :ok, state}

  @doc """
  Dispatches client `%Phoenix.Socket.Messages{}` back through Transport layer
  """
  def handle_info({:dispatch, message, ref}, state) do
    message
    |> Transport.dispatch(state.sockets, self, state.router, state.pubsub_server, LongPoller)
    |> case do
      {:ok, sockets} ->
        :ok = broadcast_from(state, {:ok, :dispatch, ref})
        {:noreply, %{state | sockets: sockets}, state.window_ms}
      {:error, reason, sockets} ->
        :ok = broadcast_from(state, {:error, :dispatch, reason, ref})
        {:noreply, %{state | sockets: sockets}, state.window_ms}
    end
  end

  @doc """
  Forwards replied/broadcasted `%Phoenix.Socket.Message{}`s from Channels back to client
  """
  def handle_info({:socket_reply, message = %Message{}}, state) do
    buffer = [message | state.buffer]
    if state.client_ref do
      :ok = broadcast_from(state, {:messages, Enum.reverse(buffer), state.client_ref})
    end
    {:noreply, %{state | buffer: buffer}, state.window_ms}
  end
  def handle_info({:socket_broadcast, message = %Message{}}, %{sockets: sockets} = state) do
    sockets = case Transport.dispatch_broadcast(sockets, message) do
      {:ok, socks} -> socks
      {:error, _reason, socks} -> socks
    end

    {:noreply, %{state | sockets: sockets}, state.window_ms}
  end

  def handle_info({:subscribe, ref}, state) do
    :ok = broadcast_from(state, {:ok, :subscribe, ref})

    {:noreply, state, state.window_ms}
  end

  def handle_info({:flush, ref}, state) do
    if Enum.any?(state.buffer) do
      :ok = broadcast_from(state, {:messages, Enum.reverse(state.buffer), ref})
    end
    {:noreply, %{state | client_ref: ref}, state.window_ms}
  end

  # TODO: %Messages{}'s need unique ids so we can properly ack them
  @doc """
  Handles acknowledged messages from client and removes from buffer.
  `:ack` calls to the server also represent the client listener
  closing for repoll.
  """
  def handle_info({:ack, messages, ref}, state) do
    # TODO remove --
    buffer = state.buffer -- messages
    :ok = broadcast_from(state, {:ok, :ack, ref})

    {:noreply, %{state | buffer: buffer}, state.window_ms}
  end


  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  def handle_info({:EXIT, _pubsub_server, :shutdown}, state) do
    {:stop, :pubsub_server_terminated, state}
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
