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
  def start_link(router, window_ms) do
    GenServer.start_link(__MODULE__, [router, window_ms])
  end

  @doc false
  def init([router, window_ms]) do
    state = %{listener: nil, buffer: [], router: router, sockets: HashDict.new, window_ms: window_ms * 2}
    {:ok, state, state.window_ms}
  end

  @doc """
  Sets active listener pid as the receiver of broadcasted messages
  """
  def handle_call({:set_active_listener, pid}, _from, state) do
    if Enum.any?(state.buffer) do
      send pid, {:messages, Enum.reverse(state.buffer)}
    end
    {:reply, :ok, %{state | listener: pid}, state.window_ms}
  end

  # TODO: %Messages{}'s need unique ids so we can properly ack them
  @doc """
  Handles acknowledged messages from client and removes from buffer.
  `:ack` calls to the server also represent the client listener
  closing for repoll.
  """
  def handle_call({:ack, messages}, _from, state) do
    buffer = state.buffer -- messages
    {:reply, :ok, %{state | buffer: buffer, listener: nil}, state.window_ms}
  end

  @doc """
  Dispatches client `%Phoenix.Socket.Messages{}` back through Transport layer
  """
  def handle_call({:dispatch, message}, _from, state) do
    message
    |> Transport.dispatch(state.sockets, self, state.router, LongPoller)
    |> case do
      {:ok, sockets} ->
        {:reply, {:ok, sockets}, %{state | sockets: sockets}, state.window_ms}
      {:error, sockets, reason} ->
        {:reply, {:error, sockets, reason}, %{state | sockets: sockets}, state.window_ms}
    end
  end

  @doc """
  Forwards replied/broadcasted `%Phoenix.Socket.Message{}`s from Channels back to client
  """
  def handle_info({:socket_reply, message = %Message{}}, state) do
    buffer = [message | state.buffer]
    if state.listener && Process.alive?(state.listener) do
      send state.listener, {:messages, buffer}
    end
    {:noreply, %{state | buffer: buffer}, state.window_ms}
  end
  def handle_info({:socket_broadcast, message = %Message{}}, %{sockets: sockets} = state) do
    sockets = case Transport.dispatch_broadcast(sockets, message, LongPoller) do
      {:ok, socks} -> socks
      {:error, socks, _reason} -> socks
    end

    {:noreply, %{state | sockets: sockets}, state.window_ms}
  end


  def handle_info(:timeout, state) do
    {:stop, :shutdown, state}
  end

  @doc """
  Forwards arbitrary Elixir messages back to listening client
  """
  def handle_info(data, state) do
    sockets = case Transport.dispatch_info(state.sockets, data, LongPoller) do
      {:ok, sockets} -> sockets
      {:error, sockets, _reason} -> sockets
    end
    {:noreply, %{state | sockets: sockets}, state.window_ms}
  end

  @doc """
  Handles forwarding arbitrary Elixir messages back to listening client
  """
  def terminate(reason, state) do
    :ok = Transport.dispatch_leave(state.sockets, reason, LongPoller)
    :ok
  end
end
