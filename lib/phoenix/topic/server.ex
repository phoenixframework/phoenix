defmodule Phoenix.Topic.Server do
  use GenServer.Behaviour
  alias Phoenix.Topic

  @garbage_collect_after_ms 60_000..120_000
  @garbage_buffer_size 1000

  defmodule State do
    defstruct role: :slave, gc_buffer: []
  end

  def start_link do
    :gen_server.start_link __MODULE__, [], []
  end

  def leader_pid, do: :global.whereis_name(__MODULE__)

  def init(_) do
    case :global.register_name(Phoenix.Topic.Server, self) do
      :no  ->
        Process.link(leader_pid)
        {:ok, %State{role: :slave}}
      :yes ->
        send(self, :garbage_collect_all)
        {:ok, %State{role: :leader}}
    end
  end

  def handle_call(_message, _from, %State{role: :slave}), do: {:stop, :error, nil, :slave}
  def handle_call({:exists?, group}, _from, state) do
    {:reply, exists?(group), state}
  end

  def handle_call({:active?, group}, _from, state) do
    {:reply, active?(group), state}
  end

  def handle_call({:create, group}, _from, state) do
    if exists?(group) do
      {:reply, :ok, state}
    else
      :ok = :pg2.create(group)
      {:reply, :ok, mark_for_garbage_collect(state, [group])}
    end
  end

  def handle_call({:subscribe, pid, group}, _from, state) do
    {:reply, :pg2.join(group, pid), state}
  end

  def handle_call({:unsubscribe, pid, group}, _from, state) do
    {:reply, :pg2.leave(group, pid), state}
  end

  def handle_call({:delete, group}, _from, state) do
    {:reply, delete(group), state}
  end

  def handle_info(_message, %State{role: :slave}), do: {:stop, :error, nil, :slave}

  def handle_info({:garbage_collect, groups}, state) do
    active_groups = Enum.filter groups, fn group ->
      if active?(group) do
        true
      else
        delete(group)
        false
      end
    end

    {:noreply, mark_for_garbage_collect(state, active_groups)}
  end

  def handle_info(:garbage_collect_all, state) do
    Topic.list
    |> Stream.chunk(@garbage_buffer_size)
    |> Enum.each fn groups ->
      mark_for_garbage_collect(state, groups)
    end
    {:noreply, state}
  end

  def terminate(_reason, timer) do
    :timer.cancel(timer)
    :ok
  end

  defp exists?(group) do
    case :pg2.get_closest_pid(group) do
      pid when is_pid(pid)          -> true
      {:error, {:no_process, _}}    -> true
      {:error, {:no_such_group, _}} -> false
    end
  end

  defp active?(group) do
    case :pg2.get_closest_pid(group) do
      pid when is_pid(pid) -> true
      _ -> false
    end
  end

  defp delete(group), do: :pg2.delete(group)

  defp mark_for_garbage_collect(state, groups) do
    state         = %State{state | gc_buffer: state.gc_buffer ++ groups}
    groups_to_gc  = state.gc_buffer |> Enum.take(@garbage_buffer_size)
    new_gc_buffer = state.gc_buffer -- groups_to_gc

    if Enum.count(groups_to_gc) >= @garbage_buffer_size do
      @garbage_collect_after_ms
      |> rand_int_between
      |> :timer.send_after({:garbage_collect, groups_to_gc})

      %State{state | gc_buffer: new_gc_buffer}
    else
      state
    end
  end

  defp rand_int_between(lower..upper) do
    :random.uniform(upper - lower) + lower
  end
end

