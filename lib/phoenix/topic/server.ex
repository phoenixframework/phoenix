defmodule Phoenix.Topic.Server do
  use GenServer.Behaviour
  alias Phoenix.Topic

  @garbage_collect_after_ms 30_000..180_000

  def start_link do
    :gen_server.start_link __MODULE__, [], []
  end

  def leader_pid, do: :global.whereis_name(__MODULE__)

  def init(_) do
    case :global.register_name(Phoenix.Topic.Server, self) do
      :no  ->
        Process.link(leader_pid)
        {:ok, :slave}
      :yes ->
        send(self, :garbage_collect_all)
        {:ok, :leader}
    end
  end

  def handle_cast(_message, :slave), do: {:stop, :error, :slave}

  def handle_call(_message, _from, :slave), do: {:stop, :error, nil, :slave}
  def handle_call({:exists?, group}, _from, state) do
    {:reply, exists?(group), state}
  end

  def handle_call({:active?, group}, _from, state) do
    {:reply, active?(group), state}
  end

  def handle_call({:create, group}, _from, state) do
    unless exists?(group) do
      :ok = :pg2.create(group)
      mark_for_garbage_collect(group)
    end
    {:reply, :ok, state}
  end

  def handle_call({:subscribe, pid, group}, _from, state) do
    {:reply, :pg2.join(group, pid), state}
  end

  def handle_call({:unsubscribe, pid, group}, _from, state) do
    {:reply, :pg2.leave(group, pid), state}
  end

  def handle_call({:subscribers, group}, _from, state) do
    {:reply, subscribers(group), state}
  end

  def handle_call({:delete, group}, _from, state) do
    {:reply, delete(group), state}
  end

  def handle_info(_message, :slave), do: {:stop, :error, nil, :slave}

  def handle_info({:garbage_collect, group}, state) do
    if active?(group) do
      mark_for_garbage_collect(group)
    else
      delete(group)
    end
    {:noreply, state}
  end

  def handle_info(:garbage_collect_all, state) do
    Enum.each Topic.list, fn group ->
      mark_for_garbage_collect(group)
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

  defp subscribers(group) do
    case :pg2.get_members(group) do
      {:error, {:no_such_group, _}} -> []
      members -> members
    end
  end

  defp delete(group), do: :pg2.delete(group)

  defp mark_for_garbage_collect(group) do
    @garbage_collect_after_ms
    |> rand_int
    |> :timer.send_after({:garbage_collect, group})
  end

  defp rand_int(lower..upper) do
    :random.uniform(upper - lower) + lower
  end
end

