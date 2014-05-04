defmodule Phoenix.Topic.GarbageCollector do
  alias Phoenix.Topic
  alias Phoenix.Topic.Server

  @buffer_size 250

  def mark_all(state) do
    Topic.list
    |> Stream.chunk(@buffer_size)
    |> Enum.reduce state, fn groups, new_state ->
      mark(new_state, groups)
    end
  end

  def mark(state, groups) do
    state         = %Server{state | gc_buffer: state.gc_buffer ++ groups}
    groups_to_gc  = state.gc_buffer |> Enum.take(@buffer_size)

    if Enum.count(groups_to_gc) >= @buffer_size do
      schedule_garbage_collect(state, groups_to_gc)

      %Server{state | gc_buffer: state.gc_buffer -- groups_to_gc}
    else
      state
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
