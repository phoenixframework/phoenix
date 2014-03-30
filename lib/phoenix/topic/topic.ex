defmodule Phoenix.Topic do
  use GenServer.Behaviour

  @pg_prefix "phx:"
  @garbage_collect_after_ms 60 * 1000 # 1 minute

  @doc """
  Creates a Topic for pubsub broadcast to subscribers
  """
  def create(name, opts \\ []) do
    if exists?(name) do
      :ok
    else
      gc_after_ms = Dict.get opts, :garbage_collect_after_ms,
                                   @garbage_collect_after_ms
      {:ok, _} = :gen_server.start(__MODULE__, [name, gc_after_ms], [])
      :ok
    end
  end

  def exists?(name) do
    case :pg2.get_closest_pid(group(name)) do
      pid when is_pid(pid)          -> true
      {:error, {:no_process, _}}    -> true
      {:error, {:no_such_group, _}} -> false
    end
  end

  def delete(name) do
    :pg2.delete(group(name))
  end

  def subscribe(name, pid) do
    :ok = create(name)
    :pg2.join(group(name), pid)
  end

  def unsubscribe(name, pid) do
    :pg2.leave(group(name), pid)
  end

  def subscribers(name) do
    :pg2.get_members(group(name))
  end

  def broadcast(name, from_pid \\ nil, message) do
    name
    |> subscribers
    |> Enum.each fn
      pid when pid != from_pid -> send(pid, message)
      _pid ->
    end
  end

  def group(name), do: "#{@pg_prefix}#{name}"

  def active?(name), do: exists?(name) && Enum.any?(subscribers(name))

  def init([name, garbage_collect_after_ms]) do
    :ok = :pg2.create(group(name))
    {:ok, timer} = :timer.send_interval(garbage_collect_after_ms , :garbage_collect)
    {:ok, {name, timer}}
  end

  def handle_info(:garbage_collect, state = {name, _timer}) do
    if active?(name) do
      {:noreply, state}
    else
      {:stop, :shutdown, state}
    end
  end

  def terminate(_reason, {name, timer}) do
    :timer.cancel(timer)
    delete(name)
    :ok
  end
end

