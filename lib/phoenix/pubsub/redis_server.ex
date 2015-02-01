defmodule Phoenix.PubSub.RedisServer do
  use GenServer
  require Logger

  @moduledoc """
  `Phoenix.PubSub` adapter for Redis

  See `Phoenix.PubSub.Redis` for details and configuration options.
  """

  @reconnect_after_ms 5000
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
    :poolboy.transaction pool_name, fn eredis_conn ->
      case GenServer.call(eredis_conn, :eredis) do
        {:ok, eredis_pid} ->
          case :eredis.q(eredis_pid, ["PUBLISH", namespace, redis_msg]) do
            {:ok, _}         -> :ok
            {:error, reason} -> {:error, reason}
          end

        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Initializes the server.

  An initial connection establishment loop is entered. Once `:eredis_sub`
  is started successfully, it handles reconnections automatically, so we
  pass off reconnection handling once we find an initial connection.
  """
  def init(opts) do
    Process.flag(:trap_exit, true)
    send(self, :establish_conn)

    {:ok, %{local_name: Keyword.fetch!(opts, :local_name),
            pool_name: Keyword.fetch!(opts, :pool_name),
            namespace: redis_namespace(Keyword.fetch!(opts, :name)),
            eredis_sub_pid: nil,
            status: :disconnected,
            node_ref: nil,
            opts: opts}}
  end

  def handle_call({:subscribe, pid, topic, link}, _from, state) do
    response = {:perform, {GenServer, :call, [state.local_name, {:subscribe, pid, topic, link}]}}
    {:reply, response, state}
  end

  def handle_call({:unsubscribe, pid, topic}, _from, state) do
    response = {:perform, {GenServer, :call, [state.local_name, {:unsubscribe, pid, topic}]}}
    {:reply, response, state}
  end

  def handle_call({:subscribers, topic}, _from, state) do
    response = {:perform, {GenServer, :call, [state.local_name, {:subscribers, topic}]}}
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
  def handle_info({:message, _redis_topic, bin_msg, _cli_pid}, state) do
    {_vsn, remote_node_ref, from_pid, topic, msg} = :erlang.binary_to_term(bin_msg)

    if remote_node_ref == state.node_ref do
      GenServer.call(state.local_name, {:broadcast, from_pid, topic, msg})
    else
      GenServer.call(state.local_name, {:broadcast, :none, topic, msg})
    end

    :eredis_sub.ack_message(state.eredis_sub_pid)
    {:noreply, state}
  end

  def handle_info({:EXIT, _pid, {:connection_error, {:connection_error, :econnrefused}}}, state) do
    {:noreply, state}
  end

  def handle_info({:EXIT, eredis_sub_pid, _}, %{eredis_sub_pid: eredis_sub_pid} = state) do
    send(self, :establish_conn)
    {:noreply, %{state | status: :disconnected, eredis_sub_pid: nil}}
  end

  @doc """
  Connection establishment and shutdown loop

  On init, an initial conection to redis is attempted when starting `:eredis_sub`
  """
  def handle_info(:establish_conn, state) do
    handle_establish_conn(state)
  end

  def handle_info({:subscribed, _pattern, _client_pid}, state) do
    :eredis_sub.ack_message(state.eredis_sub_pid)
    {:noreply, state}
  end

  def handle_info({:eredis_connected, _client_pid}, state) do
    Logger.info "redis connection re-established"
    establish_success(state.eredis_sub_pid, state)
  end

  def handle_info({:eredis_disconnected, _client_pid}, state) do
    Logger.error "lost redis connection. Attempting to reconnect..."
    {:noreply, %{state | status: :disconnected}}
  end

  def terminate(_reason, %{status: :disconnected}) do
    :ok
  end
  def terminate(_reason, state) do
    :eredis_client.stop(state.eredis_sub_pid)
    :ok
  end

  defp redis_namespace(server_name), do: "phx:#{server_name}"

  defp handle_establish_conn(state) do
    case :eredis_sub.start_link(state.opts) do
      {:ok, eredis_sub_pid} -> establish_success(eredis_sub_pid, state)
      _error                -> establish_failed(state)
     end
  end
  defp establish_failed(state) do
    Logger.error "unable to establish redis connection. Attempting to reconnect..."
    :timer.send_after(@reconnect_after_ms, :establish_conn)
    {:noreply, %{state | status: :disconnected}}
  end
  defp establish_success(eredis_sub_pid, state) do
    :eredis_sub.controlling_process(eredis_sub_pid)
    :eredis_sub.subscribe(eredis_sub_pid, [state.namespace])

    {:noreply, %{state | eredis_sub_pid: eredis_sub_pid,
                         status: :connected,
                         node_ref: make_node_ref(state)}}
  end

  defp make_node_ref(state) do
    :poolboy.transaction state.pool_name, fn eredis_conn ->
      {:ok, eredis_pid} = GenServer.call(eredis_conn, :eredis)
      {:ok, count} = :eredis.q(eredis_pid, ["INCR", "#{state.namespace}:node_counter"])

      count
    end
  end
end
