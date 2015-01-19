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
  alias Phoenix.PubSub.GarbageCollector

  @moduledoc """
  The server for the RedisAdapter

  See `Phoenix.PubSub.RedisAdapter` for details and configuration options.
  """

  @derive [Access]
  defstruct gc_buffer: [],
            garbage_collect_after_ms: nil,
            topics: nil,
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

    {:ok, struct(RedisServer, topics: HashDict.new,
                              eredis_sub_pid: eredis_sub_pid,
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
      state =
        state
        |> put_in([:topics], HashDict.put(state.topics, group, HashSet.new))
        |> gc_mark(group)

      {:reply, :ok, state}
    end
  end

  def handle_call({:subscribe, pid, group}, _from, state) do
    members = subscribers(state, group)
    state = put_in(state.topics, HashDict.put(state.topics, group, HashSet.put(members, pid)))
    {:reply, :ok, state}
  end

  def handle_call({:unsubscribe, pid, group}, _from, state) do
    members = state |> subscribers(group) |> HashSet.delete(pid)
    state =
      state
      |> put_in([:topics], HashDict.put(state.topics, group, members))
      |> gc_mark(group)

    {:reply, :ok, state}
  end

  def handle_call({:delete, group}, _from, state) do
    if group_active?(state, group) do
      {:reply, {:error, :active}, state}
    else
      :ok = :eredis.unsubscribe(state.eredis_sub_pid, [group])
      {:reply, :ok, delete_group(state, group)}
    end
  end

  def handle_call(:list, _from, state) do
    {:reply, list(state), state}
  end

  def handle_call({:subscribers, group}, _from, state) do
    pids = state |> subscribers(group) |> Enum.to_list
    {:reply, pids, state}
  end

  def handle_call(:stop, _from, state) do
    :eredis_client.stop(state.eredis_pid)
    case :eredis_client.stop(state.eredis_sub_pid) do
      :ok -> {:stop, :normal, :ok, state}
      err -> {:stop, err, {:error, err}, state}
    end
  end

  def handle_call({:broadcast, from_pid, group, msg}, _from, state) do
    :eredis.q(state.eredis_pid, ["PUBLISH", group, {from_pid, msg}])
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
    {:noreply, gc_mark(state, list(state))}
  end

  def handle_info({:subscribed, "phx:*", _client_pid}, state) do
    :eredis_sub.ack_message(state.eredis_sub_pid)
    {:noreply, state}
  end

  def handle_info({:pmessage, "phx:*", group, binary_msg, _client_pid}, state) do
    {from_pid, msg} = :erlang.binary_to_term(binary_msg)

    state
    |> subscribers(group)
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

  defp group_exists?(state, group) do
    case HashDict.get(state.topics, group) do
      nil -> false
      _   -> true
    end
  end

  defp group_active?(state, group) do
    HashSet.size(subscribers(state, group)) > 0
  end

  defp delete_group(state, group) do
    put_in state.topics, HashDict.drop(state.topics, group)
  end

  defp gc_mark(state, group) do
    buffer = GarbageCollector.mark(state.gc_buffer, state.garbage_collect_after_ms, group)
    %RedisServer{state | gc_buffer: buffer}
  end

  defp list(state) do
    HashDict.keys(state.topics)
  end

  defp subscribers(state, group) do
    HashDict.get(state.topics, group, HashSet.new)
  end
end
