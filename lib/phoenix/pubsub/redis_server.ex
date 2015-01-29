defmodule Phoenix.PubSub.RedisServer do
  use GenServer
  require Logger

  @moduledoc """
  The server for the RedisAdapter

  See `Phoenix.PubSub.RedisAdapter` for details and configuration options.
  """

  @defaults [host: "127.0.0.1", port: 6379, password: ""]

  @max_connect_attemps 3   # 15s to establish connection
  @reconnect_after_ms 5000

  @doc """
  Starts the server

  TODO document options
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
    server_name = opts[:name]
    {:ok, local_pid} = Phoenix.PubSub.Local.start_link(Module.concat(server_name, Local))
    opts = Dict.merge(@defaults, opts)
    opts = Dict.merge(opts, host: String.to_char_list(to_string(opts[:host])),
                            password: String.to_char_list(to_string(opts[:password])))

    Process.flag(:trap_exit, true)
    send(self, :establish_conn)

    {:ok, %{name: server_name,
            eredis_sub_pid: nil,
            status: :disconnected,
            node_ref: :erlang.make_ref,
            local_pid: local_pid,
            reconnect_attemps: 0,
            opts: opts}}
  end

  def handle_call({:subscribe, pid, topic}, _from, state) do
    {:reply, GenServer.call(state.local_pid, {:subscribe, pid, topic}), state}
  end

  def handle_call({:unsubscribe, pid, topic}, _from, state) do
    {:reply, GenServer.call(state.local_pid, {:unsubscribe, pid, topic}), state}
  end

  def handle_call({:subscribers, topic}, _from, state) do
    {:reply, GenServer.call(state.local_pid, {:subscribers, topic}), state}
  end

  def handle_call(:list, _from, state) do
    {:reply, GenServer.call(state.local_pid, :list), state}
  end

  def handle_call({:broadcast, from_pid, topic, msg}, _from, state) do
    result = :poolboy.transaction :phx_redis_pool, fn worker_pid ->
      GenServer.call(worker_pid, {:publish_to_redis, namespace(state, topic),
                                 {1, state.node_ref, from_pid, msg}})
    end
    {:reply, result, state}
  end

  # Removes redis pool
  def handle_info({:pmessage, _pattern, namespaced_topic, binary_msg, _client_pid}, state) do
    {:ok, topic} = remove_namespace(state, namespaced_topic)
    :poolboy.transaction :phx_redis_pool, fn worker_pid ->
      GenServer.cast(worker_pid, {:forward_to_subscribers,
                                  state.local_pid, state.node_ref, topic, binary_msg})
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
  def handle_info(:establish_conn, %{reconnect_attemps: count} = state)
    when count >= @max_connect_attemps do

    {:stop, :exceeded_max_conn_attempts, state}
  end
  def handle_info(:establish_conn, state) do
    case :eredis_sub.start_link(state.opts) do
      {:ok, eredis_sub_pid} ->
        :eredis_sub.controlling_process(eredis_sub_pid)
        :eredis_sub.psubscribe(eredis_sub_pid, [namespace(state, "*")])

         {:noreply, %{state | eredis_sub_pid: eredis_sub_pid,
                              status: :connected,
                              reconnect_attemps: 0}}
      _error ->
        Logger.error "unable to establish redis connection. Attempting to reconnect..."
        :timer.send_after(@reconnect_after_ms, :establish_conn)
        {:noreply, %{state | status: :disconnected,
                             reconnect_attemps: state.reconnect_attemps + 1}}
     end
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
      :ok -> :ok
      err -> {:error, err}
    end
  end

  defp namespace(state, topic), do: "phx:#{state.name}:#{topic}"

  defp remove_namespace(state, namespaced_topic) do
    namespaced_topic
    |> String.split("phx:#{state.name}:", parts: 2)
    |> case do
      [_, topic] -> {:ok, topic}
      _          -> {:error, :bad_topic}
    end
  end
end
