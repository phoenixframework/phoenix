defmodule Phoenix.PubSub.RedisServer do
  use GenServer
  require Logger
  alias Phoenix.PubSub.Local

  @moduledoc """
  `Phoenix.PubSub` adapter for Redis

  See `Phoenix.PubSub.Redis` for details and configuration options.
  """

  @reconnect_after_ms 5_000
  @redis_msg_vsn 1

  @doc """
  Starts the server
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Dict.fetch!(opts, :name))
  end

  @doc """
  Broadcasts message to redis. To be only called from {:perform, {m, f, a}}
  response to clients
  """
  def broadcast(namespace, pool_name, redis_msg) do
    :poolboy.transaction pool_name, fn worker_pid ->
      bin_msg = :erlang.term_to_binary(redis_msg)
      case GenServer.call(worker_pid, :conn) do
        {:ok, conn_pid} ->
          case :redo.cmd(conn_pid, ["PUBLISH", namespace, bin_msg]) do
            {:error, reason} -> {:error, reason}
            _ -> :ok
          end

        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Initializes the server.

  An initial connection establishment loop is entered. Once `:redo`
  is started successfully, it handles reconnections automatically, so we
  pass off reconnection handling once we find an initial connection.
  """
  def init(opts) do
    Process.flag(:trap_exit, true)
    send(self, :establish_conn)

    {:ok, %{local_name: Keyword.fetch!(opts, :local_name),
            pool_name: Keyword.fetch!(opts, :pool_name),
            namespace: redis_namespace(Keyword.fetch!(opts, :name)),
            redo_pid: nil,
            redo_ref: nil,
            status: :disconnected,
            node_ref: nil,
            opts: opts}}
  end

  def handle_call({:subscribe, pid, topic, opts}, _from, state) do
    response = {:perform, {Local, :subscribe, [state.local_name, pid, topic, opts]}}
    {:reply, response, state}
  end

  def handle_call({:unsubscribe, pid, topic}, _from, state) do
    response = {:perform, {Local, :unsubscribe, [state.local_name, pid, topic]}}
    {:reply, response, state}
  end

  def handle_call({:broadcast, from_pid, topic, msg}, _from, state) do
    redis_msg = {@redis_msg_vsn, state.node_ref, from_pid, topic, msg}
    resp = {:perform, {__MODULE__, :broadcast, [state.namespace, state.pool_name, redis_msg]}}
    {:reply, resp, state}
  end

  @doc """
  Decodes binary message and fowards to local subscribers of topic
  """

  def handle_info({ref, ["subscribe", _, _]}, %{redo_ref: ref} = state) do
    {:noreply, state}
  end

  def handle_info({ref, ["message", _redis_topic, bin_msg]}, %{redo_ref: ref} = state) do
    {_vsn, remote_node_ref, from_pid, topic, msg} = :erlang.binary_to_term(bin_msg)

    if remote_node_ref == state.node_ref do
      Local.broadcast(state.local_name, from_pid, topic, msg)
    else
      Local.broadcast(state.local_name, :none, topic, msg)
    end

    {:noreply, state}
  end

  def handle_info({ref, :closed}, %{redo_ref: ref} = state) do
    :ok = :redo.shutdown(state.redo_pid)
    establish_failed(state)
  end

  def handle_info({:EXIT, redo_pid, _}, %{redo_pid: redo_pid} = state) do
    establish_failed(state)
  end

  @doc """
  Connection establishment and shutdown loop

  On init, an initial conection to redis is attempted when starting `:redo`
  """
  def handle_info(:establish_conn, state) do
    case :redo.start_link(:undefined, state.opts) do
      {:ok, redo_pid} -> establish_success(redo_pid, state)
      _error          -> establish_failed(state)
    end
  end

  def terminate(_reason, %{status: :disconnected}) do
     :ok
  end
  def terminate(_reason, state) do
    :redo.shutdown(state.redo_pid)
    :ok
  end

  defp redis_namespace(server_name), do: "phx:#{server_name}"

  defp establish_failed(state) do
    Logger.error "unable to establish redis connection. Attempting to reconnect..."
    :timer.send_after(@reconnect_after_ms, :establish_conn)
    {:noreply, %{state | status: :disconnected}}
  end
  defp establish_success(redo_pid, state) do
    ref = :redo.subscribe(redo_pid, state.namespace)
    {:noreply, %{state | redo_pid: redo_pid,
                         redo_ref: ref,
                         status: :connected,
                         node_ref: make_node_ref(state)}}
  end

  defp make_node_ref(state) do
    :poolboy.transaction state.pool_name, fn worker_pid ->
      {:ok, conn_pid} = GenServer.call(worker_pid, :conn)

      {:ok, count} = case :redo.cmd(conn_pid, ["INCR", "#{state.namespace}:node_counter"]) do
        {:error, reason} -> {:error, reason}
        count -> {:ok, count}
      end

      count
    end
  end
end
