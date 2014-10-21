defmodule Phoenix.Transports.LongPoller.Server do
  use GenServer
  alias Phoenix.Transports.LongPoller.Server

  @moduledoc false

  alias Phoenix.Socket.Message
  alias Phoenix.Channel.Transport

  # TODO: Make this confirable, and refer to `LongPoller` setting
  @timeout_ms 10_000 * 2

  defstruct listener: nil, buffer: [], router: nil, sockets: HashDict.new

  def start_link(listener, router) do
    GenServer.start_link(__MODULE__, [listener, router])
  end

  def init([listener, router]) do
    {:ok, %Server{listener: listener, router: router}, @timeout_ms}
  end

  @doc """
  Sets active listener pid as the receiver of broadcasted messages
  """
  def handle_call({:set_active_listener, pid}, _from, state) do
    if Enum.any?(state.buffer) do
      send pid, {:messages, state.buffer}
    end
    {:reply, :ok, %Server{state | listener: pid}}
  end

  # TODO: %Messages{}'s need unique ids so we can properly ack them
  def handle_call({:ack, messages}, _from, state) do
    {:reply, :ok, %Server{state | buffer: state.buffer -- messages}}
  end

  @doc """
  Dispatches client `%Phoenix.Socket.Messages{}` back through Transport layer
  """
  def handle_call({:dispatch, message}, _from, state) do
    message
    |> Transport.dispatch(state.sockets, self, state.router)
    |> case do
      {:ok, sockets} ->
        {:reply, {:ok, sockets}, %Server{state | sockets: sockets}}
      {:error, sockets, reason} ->
        {:reply, {:error, sockets, reason}, %Server{state | sockets: sockets}}
    end
  end

  @doc """
  Forwards replied/broadcasted `%Phoenix.Socket.Message{}`s from Channels back to client
  """
  def handle_info(message = %Message{}, state) do
    if Process.alive?(state.listener) do
      send state.listener, {:messages, [message]}
    end
    {:noreply, %Server{state | buffer: [message | state.buffer]}}
  end

  def handle_info(:timeout, state) do
    {:stop, :shutdown, state}
  end

  @doc """
  Forwards arbitrary Elixir messages back to listening client
  """
  def handle_info(data, state) do
    sockets = case Transport.dispatch_info(state.sockets, data) do
      {:ok, sockets} -> sockets
      {:error, sockets, _reason} -> sockets
    end
    {:noreply, %Server{state | sockets: sockets}}
  end

  @doc """
  Handles forwarding arbitrary Elixir messages back to listening client
  """
  def terminate(reason, state) do
    :ok = Transport.dispatch_leave(state.sockets, reason)
    :ok
  end
end
