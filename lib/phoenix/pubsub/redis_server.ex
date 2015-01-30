defmodule Phoenix.PubSub.RedisServer do
  use GenServer
  require Logger

  @moduledoc """
  `Phoenix.PubSub` adapter for Redis

  See `Phoenix.PubSub.Redis` for details and configuration options.
  """

  @defaults [host: "127.0.0.1", port: 6379, password: ""]

  @max_connect_attemps 3   # 15s to establish connection
  @reconnect_after_ms 5000
  @redis_msg_vsn 1

  @doc """
  Starts the server
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Dict.fetch!(opts, :name))
  end

  @doc """
  Initializes the server.

  An initial connection establishment loop is entered. Once `:eredis_sub`
  is started successfully, it handles reconnections automatically, so we
  pass off reconnection handling once we find an initial connection.
  """
  def init(opts) do
    server_name = Keyword.fetch!(opts, :name)
    local_name  = Keyword.fetch!(opts, :local_name)
    opts = Dict.merge(@defaults, opts)
    opts = Dict.merge(opts, host: String.to_char_list(to_string(opts[:host])),
                            password: String.to_char_list(to_string(opts[:password])))

    Process.flag(:trap_exit, true)
    send(self, :establish_conn)

    {:ok, %{local_name: local_name,
            namespace: redis_namespace(server_name),
            eredis_sub_pid: nil,
            eredis_pid: nil,
            status: :disconnected,
            node_ref: :erlang.make_ref,
            reconnect_attemps: 0,
            opts: opts}}
  end

  def handle_call({:subscribe, pid, topic, link}, _from, state) do
    if link, do: Process.link(pid)
    {:reply, GenServer.call(state.local_name, {:subscribe, pid, topic}), state}
  end

  def handle_call({:unsubscribe, pid, topic}, _from, state) do
    {:reply, GenServer.call(state.local_name, {:unsubscribe, pid, topic}), state}
  end

  def handle_call({:subscribers, topic}, _from, state) do
    {:reply, GenServer.call(state.local_name, {:subscribers, topic}), state}
  end

  def handle_call({:broadcast, from_pid, topic, msg}, _from, state) do
    redis_msg = {@redis_msg_vsn, state.node_ref, from_pid, topic, msg}
    case :eredis.q(state.eredis_pid, ["PUBLISH", state.namespace, redis_msg]) do
      {:ok, _}         -> {:reply, :ok, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
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

  def handle_info({:EXIT, _linked_pid, _reason}, state) do
    {:noreply, state}
  end

  @doc """
  Connection establishment and shutdown loop

  On init, an initial conection to redis is attempted when starting `:eredis_sub`.
  If failed, the connection is tried again in `@reconnect_after_ms` until a max
  of `@max_connect_attemps` is tried, at which point the server terminates with
  an `:exceeded_max_conn_attempts`.
  """
  def handle_info(:establish_conn, %{reconnect_attemps: count} = state)
    when count >= @max_connect_attemps do

    {:stop, :exceeded_max_conn_attempts, state}
  end
  def handle_info(:establish_conn, state) do
    handle_establish_conn(state)
  end

  def handle_info({:subscribed, _pattern, _client_pid}, state) do
    :eredis_sub.ack_message(state.eredis_sub_pid)
    {:noreply, state}
  end

  def handle_info({:eredis_connected, _client_pid}, state) do
    Logger.info "redis connection re-established"
    {:noreply, %{state | status: :connected}}
  end

  def handle_info({:eredis_disconnected, _client_pid}, state) do
    Logger.error "lost redis connection. Attempting to reconnect..."
    {:noreply, %{state | status: :disconnected}}
  end

  def terminate(_reason, %{status: :disconnected}) do
    :ok
  end
  def terminate(_reason, state) do
    case :eredis_client.stop(state.eredis_sub_pid) do
      :ok ->
        case :eredis_client.stop(state.eredis_pid) do
          :ok -> :ok
          err -> {:error, err}
        end
      err -> {:error, err}
    end
  end

  defp redis_namespace(server_name), do: "phx:#{server_name}"

  defp handle_establish_conn(state) do
    case {:eredis_sub.start_link(state.opts), :eredis.start_link(state.opts)} do
      {{:ok, eredis_sub_pid}, {:ok, eredis_pid}} ->
        establish_success(eredis_sub_pid, eredis_pid, state)

      {{:ok, eredis_sub_pid}, _} ->
        :ok = :eredis_client.stop(eredis_sub_pid)
        establish_failed(state)

      {_, {:ok, eredis_pid}} ->
        :ok = :eredis_client.stop(eredis_pid)
        establish_failed(state)

      _error ->
        establish_failed(state)
     end
  end
  defp establish_failed(state) do
    Logger.error "unable to establish redis connection. Attempting to reconnect..."
    :timer.send_after(@reconnect_after_ms, :establish_conn)
    {:noreply, %{state | status: :disconnected,
                         reconnect_attemps: state.reconnect_attemps + 1}}
  end
  defp establish_success(eredis_sub_pid, eredis_pid, state) do
    :eredis_sub.controlling_process(eredis_sub_pid)
    :eredis_sub.subscribe(eredis_sub_pid, [state.namespace])

    {:noreply, %{state | eredis_sub_pid: eredis_sub_pid,
                         eredis_pid: eredis_pid,
                         status: :connected,
                         reconnect_attemps: 0}}
  end
end
