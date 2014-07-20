defmodule Phoenix.Topic.GarbageCollector do
  alias Phoenix.Topic.Server

  @buffer_size 200

  @doc """
  Marks a list of topics for garbage collection
  """
  def mark(state, groups) when is_list groups do
    Enum.reduce groups, state, fn group, new_state ->
      mark(new_state, group)
    end
  end

  @doc """
  Marks an individual topic for garbage collection
  """
  def mark(state, group) do
    if Enum.count(state.gc_buffer) + 1 >= @buffer_size do
      schedule_garbage_collect(state, [group | state.gc_buffer])

      %Server{state | gc_buffer: []}
    else
      %Server{state | gc_buffer: [group | state.gc_buffer]}
    end
  end

  defp schedule_garbage_collect(state, groups_to_gc) do
    state.garbage_collect_after_ms
    |> rand_int_between
    |> :timer.send_after({:garbage_collect, groups_to_gc})
  end

  defp rand_int_between(lower..upper) do
    :random.uniform(upper - lower) + lower
  end
end
