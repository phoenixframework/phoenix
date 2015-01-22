defmodule Phoenix.PubSub.RedisServer do
  use GenServer
  require Logger
  alias Phoenix.PubSub.RedisServer
  alias Phoenix.PubSub.RedisAdapter
  alias Phoenix.PubSub.GarbageCollector

  @moduledoc """
  The server for the RedisAdapter

  See `Phoenix.PubSub.RedisAdapter` for details and configuration options.
  """

  @derive [Access]
  defstruct gc_buffer: [],
            garbage_collect_after_ms: nil,
            eredis_sub_pid: nil,
            status: :disconnected,
            reconnect_attemps: 0,
            node_ref: nil,
            opts: []

  @defaults [host: "127.0.0.1", port: 6379, password: ""]

  @max_connect_attemps 3   # 15s to establish connection
  @reconnect_after_ms 5000

  @doc """
  Starts the server

  TODO document options
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Initializes the server.

  An initial connection establishment loop is entered. Once `:eredis_sub`
  is started successfully, it handles reconnections automatically, so we
  pass off reconnection handling once we find an initial connection.
  """
  def init(opts) do
    gc_after = Dict.fetch!(opts, :garbage_collect_after_ms)
    opts = Dict.merge(@defaults, opts)
    opts = Dict.merge(opts, host: String.to_char_list(to_string(opts[:host])),
                            password: String.to_char_list(to_string(opts[:password])))

    Process.flag(:trap_exit, true)
    send(self, :establish_conn)
    send(self, :garbage_collect_all)


    {:ok, struct(RedisServer, opts: opts,
                              garbage_collect_after_ms: gc_after,
                              node_ref: :erlang.make_ref)}
  end

  def handle_call({:exists?, group}, _from, state) do
    {:reply, group_exists?(state, group), state}
  end

  def handle_call({:active?, group}, _from, state) do
    {:reply, group_active?(state, group), state}
  end

  def handle_call({:create, group}, _from, state) do
    if group_exists?(state, group) do
      {:reply, :ok, state}
    else
      :ok = :pg2.create(group)
      {:reply, :ok, gc_mark(state, group)}
    end
  end

  def handle_call({:subscribe, pid, group}, _from, state) do
    {:reply, :pg2.join(group, pid), state}
  end

  def handle_call({:unsubscribe, pid, group}, _from, state) do
    {:reply, :pg2.leave(group, pid), state}
  end

  def handle_call({:delete, group}, _from, state) do
    if group_active?(state, group) do
      {:reply, {:error, :active}, state}
    else
      {:reply, :ok, delete_group(state, group)}
    end
  end

  def handle_call({:broadcast, from_pid, topic, msg}, _from, state) do
    with_conn state, fn state ->
      result = :poolboy.transaction :phx_redis_pool, fn worker_pid ->
        GenServer.call(worker_pid, {:publish_to_redis, "phx:#{topic}",
                                   {1, state.node_ref, from_pid, msg}})
      end
      {:reply, result, state}
    end
  end

  def handle_info({:pmessage, "phx:*", "phx:" <> topic, binary_msg, _client_pid}, state) do
    :poolboy.transaction :phx_redis_pool, fn worker_pid ->
      GenServer.cast(worker_pid, {:forward_to_subscribers, state.node_ref, topic, binary_msg})
    end

    :eredis_sub.ack_message(state.eredis_sub_pid)
    {:noreply, state}
  end

  def handle_info({:EXIT, _pid, {:connection_error, {:connection_error, :econnrefused}}}, state) do
    {:noreply, state}
  end

  @doc """
  Connection establishment and shutdown loop

  On init, an initial conection to redis is attempted when starting `:eredis_sub`.
  If failed, the connection is tried again in `@reconnect_after_ms` until a max
  of `@max_connect_attemps` is tried, at which point the server terminates with
  an `:exceeded_max_conn_attempts`.
  """
  def handle_info(:establish_conn, %RedisServer{status: :connected} = state) do
    {:noreply, state}
  end
  def handle_info(:establish_conn, %RedisServer{reconnect_attemps: count} = state)
    when count >= @max_connect_attemps do

    {:stop, :exceeded_max_conn_attempts, state}
  end
  def handle_info(:establish_conn, state) do
    case :eredis_sub.start_link(state.opts) do
      {:ok, eredis_sub_pid} ->
        :eredis_sub.controlling_process(eredis_sub_pid)
        :eredis_sub.psubscribe(eredis_sub_pid, ["phx:*"])

         {:noreply, %RedisServer{state | eredis_sub_pid: eredis_sub_pid,
                                         status: :connected,
                                         reconnect_attemps: 0}}
      _error ->
        Logger.error fn -> "#{inspect __MODULE__} unable to establish redis connection. Attempting to reconnect..." end
        :timer.send_after(@reconnect_after_ms, :establish_conn)
        {:noreply, %RedisServer{state | status: :disconnected,
                                        reconnect_attemps: state.reconnect_attemps + 1}}
     end
  end

  def handle_info({:garbage_collect, groups}, state) do
    {state, active_groups} = Enum.reduce groups, {state, []}, fn group, {state, acc} ->
      if group_active?(state, group) do
        {state, [group | acc]}
      else
        {delete_group(state, group), acc}
      end
    end

    {:noreply, gc_mark(state, active_groups)}
  end

  def handle_info(:garbage_collect_all, state) do
    {:noreply, gc_mark(state, RedisAdapter.list)}
  end

  def handle_info({:subscribed, "phx:*", _client_pid}, state) do
    :eredis_sub.ack_message(state.eredis_sub_pid)
    {:noreply, state}
  end

  def handle_info({:eredis_connected, _client_pid}, state) do
    Logger.info fn -> "#{inspect __MODULE__} redis connection re-established" end
    {:noreply, %RedisServer{state | status: :connected}}
  end

  def handle_info({:eredis_disconnected, _client_pid}, state) do
    Logger.error fn -> "#{inspect __MODULE__} lost redis connection. Attempting to reconnect..." end
    {:noreply, %RedisServer{state | status: :disconnected}}
  end

  def terminate(_reason, %{status: :disconnected}) do
    :ok
  end
  def terminate(_reason, state) do
    case :eredis_client.stop(state.eredis_sub_pid) do
      :ok -> :ok
      err -> {:error, err}
    end
  end

  defp group_exists?(_state, group) do
    case :pg2.get_closest_pid(group) do
      pid when is_pid(pid)          -> true
      {:error, {:no_process, _}}    -> true
      {:error, {:no_such_group, _}} -> false
    end
  end

  defp group_active?(_state, group) do
    case :pg2.get_closest_pid(group) do
      pid when is_pid(pid) -> true
      _ -> false
    end
  end

  defp delete_group(state, group) do
    :pg2.delete(group)
    state
  end

  defp gc_mark(state, group) do
    buffer = GarbageCollector.mark(state.gc_buffer, state.garbage_collect_after_ms, group)
    %RedisServer{state | gc_buffer: buffer}
  end

  # Ensures an established connection exists for the callback.
  # If no connection exists, `{:reply, {:error, :no_connection}, state}`
  # is returned and the callback is not invoked
  defp with_conn(%RedisServer{status: :connected} = state, func) do
    func.(state)
  end
  defp with_conn(%RedisServer{status: :disconnected} = state, _func) do
    {:reply, {:error, :no_connection}, state}
  end
end
