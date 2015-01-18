defmodule Phoenix.PubSub.PG2Server do
  use GenServer
  alias Phoenix.PubSub.PG2Server
  alias Phoenix.PubSub.PG2Adapter
  alias Phoenix.PubSub.GarbageCollector

  @moduledoc """
  The server for the PG2Adapter

  See `Phoenix.PubSub.PG2Adapter` for details and configuration options.
  """

  defstruct role: :slave,
            gc_buffer: [],
            garbage_collect_after_ms: nil

  def init(opts) do
    gc_after = Dict.fetch!(opts, :garbage_collect_after_ms)

    case :global.register_name(__MODULE__, self, &:global.notify_all_name/3) do
      :no  ->
        Process.link(PG2Adapter.leader_pid)
        {:ok, struct(PG2Server, role: :slave, garbage_collect_after_ms: gc_after)}
      :yes ->
        send(self, :garbage_collect_all)
        {:ok, struct(PG2Server, role: :leader, garbage_collect_after_ms: gc_after)}
    end
  end

  def handle_call(_message, _from, state = %PG2Server{role: :slave}) do
    {:stop, :error, nil, state}
  end

  def handle_call({:exists?, group}, _from, state) do
    {:reply, group_exists?(group), state}
  end

  def handle_call({:active?, group}, _from, state) do
    {:reply, group_active?(group), state}
  end

  def handle_call({:create, group}, _from, state) do
    if group_exists?(group) do
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
    if group_active?(group) do
      {:reply, {:error, :active}, state}
    else
      {:reply, delete_group(group), state}
    end
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, state}
  end

  def handle_info(_message, state = %PG2Server{role: :slave}) do
    {:stop, :error, nil, state}
  end

  def handle_info({:garbage_collect, groups}, state) do
    active_groups = Enum.filter groups, fn group ->
      if group_active?(group) do
        true
      else
        delete_group(group)
        false
      end
    end

    {:noreply, gc_mark(state, active_groups)}
  end

  def handle_info({:global_name_conflict, name, _other_pid}, state) do
    {:stop, {:global_name_conflict, name}, state}
  end

  def handle_info(:garbage_collect_all, state) do
    {:noreply, gc_mark(state, PG2Adapter.list)}
  end

  defp group_exists?(group) do
    case :pg2.get_closest_pid(group) do
      pid when is_pid(pid)          -> true
      {:error, {:no_process, _}}    -> true
      {:error, {:no_such_group, _}} -> false
    end
  end

  defp group_active?(group) do
    case :pg2.get_closest_pid(group) do
      pid when is_pid(pid) -> true
      _ -> false
    end
  end

  defp delete_group(group), do: :pg2.delete(group)

  defp gc_mark(state, group) do
    buffer = GarbageCollector.mark(state.gc_buffer, state.garbage_collect_after_ms, group)
    %PG2Server{state | gc_buffer: buffer}
  end
end
