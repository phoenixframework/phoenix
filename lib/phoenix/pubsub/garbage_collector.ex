defmodule Phoenix.PubSub.GarbageCollector do

  @buffer_size 200

  @doc """
  Marks a list of topics for garbage collection
  """
  def mark(buffer, after_ms, groups) when is_list groups do
    Enum.reduce groups, buffer, fn group, new_buffer ->
      mark(new_buffer, after_ms, group)
    end
  end

  @doc """
  Marks an individual topic for garbage collection
  """
  def mark(buffer, after_ms, group) do
    if Enum.count(buffer) + 1 >= @buffer_size do
      schedule_garbage_collect(after_ms, [group | buffer])

      []
    else
      [group | buffer]
    end
  end

  defp schedule_garbage_collect(after_ms, groups_to_gc) do
    after_ms
    |> rand_int_between
    |> :timer.send_after({:garbage_collect, groups_to_gc})
  end

  defp rand_int_between(lower..upper) do
    :random.uniform(upper - lower) + lower
  end
end
