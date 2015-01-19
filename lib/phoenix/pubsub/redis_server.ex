defmodule Phoenix.PubSub.RedisSupervisor do
  use Supervisor

  @moduledoc false

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    children = [
      worker(Phoenix.PubSub.RedisServer, [opts]),
    ]
    supervise children, strategy: :one_for_one, max_restarts: 1_000_000
  end
end

defmodule Phoenix.PubSub.RedisServer do
  use GenServer
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
            eredis_pid: nil

  @defaults [host: "127.0.0.1", port: 6379, password: ""]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    gc_after = Dict.fetch!(opts, :garbage_collect_after_ms)
    opts = Dict.merge(@defaults, opts)
    opts = Dict.merge(opts, host: String.to_char_list(to_string(opts[:host])),
                            password: String.to_char_list(to_string(opts[:password])))

    {:ok, eredis_sub_pid} = :eredis_sub.start_link(opts)
    {:ok, eredis_pid}     = :eredis.start_link(opts)

    :eredis_sub.controlling_process(eredis_sub_pid)
    :eredis_sub.psubscribe(eredis_sub_pid, ["phx:*"])

    send(self, :garbage_collect_all)

    {:ok, struct(RedisServer, eredis_sub_pid: eredis_sub_pid,
                              eredis_pid: eredis_pid,
                              garbage_collect_after_ms: gc_after)}
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

  def handle_call(:stop, _from, state) do
    :eredis_client.stop(state.eredis_pid)
    case :eredis_client.stop(state.eredis_sub_pid) do
      :ok -> {:stop, :normal, :ok, state}
      err -> {:stop, err, {:error, err}, state}
    end
  end

  def handle_call({:broadcast, from_pid, topic, msg}, _from, state) do
    :eredis.q(state.eredis_pid, ["PUBLISH", "phx:#{topic}", {from_pid, msg}])
    {:reply, :ok, state}
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

  def handle_info({:pmessage, "phx:*", "phx:" <> topic, binary_msg, _client_pid}, state) do
    {from_pid, msg} = :erlang.binary_to_term(binary_msg)

    topic
    |> RedisAdapter.subscribers
    |> Enum.each fn
      pid when pid != from_pid -> send(pid, msg)
      _pid -> :ok
    end

    :eredis_sub.ack_message(state.eredis_sub_pid)
    {:noreply, state}
  end

  def handle_info({:eredis_disconnected, _client_pid}, state) do
    {:stop, :eredis_disconnected, state}
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
end
