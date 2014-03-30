defmodule Phoenix.Topic do
  use GenServer.Behaviour

  @pg_prefix "phx:"
  @garbage_collect_after_ms 60 * 1000 # 1 minute

  @doc """
  Creates a Topic for pubsub broadcast to subscribers

  name - The String name of the topic
  opts - The optional Dict options
    garbage_collect_after_ms - The interval of milliseconds to wait until
                               checking topic for removal due to inactivity

  Examples

  iex> Topic.create("mytopc")
  :ok
  iex> Topic.create("mytopc", garbage_collect_after_ms: 1000)
  :ok

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

  @doc """
  Checks if a given Topic is registered as a process group
  """
  def exists?(name) do
    case :pg2.get_closest_pid(group(name)) do
      pid when is_pid(pid)          -> true
      {:error, {:no_process, _}}    -> true
      {:error, {:no_such_group, _}} -> false
    end
  end


  @doc """
  Removes Topic from process group
  """
  def delete(name) do
    :pg2.delete(group(name))
  end

  @doc """
  Adds subsriber pid to given Topic process group

  Examples

  iex> Topic.subscribe("mytopic", self)
  """
  def subscribe(name, pid) do
    :ok = create(name)
    :pg2.join(group(name), pid)
  end

  @doc """
  Removes the given subscriber from the Topic's process group

  Examples

  iex> Topic.unsubscribe("mytopic", self)
  """
  def unsubscribe(name, pid) do
    :pg2.leave(group(name), pid)
  end

  @doc """
  Returns the List of subsriber pids of the Topic's process group

  iex> Topic.subscribers("mytopic")
  []
  iex> Topic.subscribe("mytopic", self)
  :ok
  iex> Topic.subscribers("mytopic")
  [#PID<0.41.0>]

  """
  def subscribers(name) do
    :pg2.get_members(group(name))
  end

  @doc """
  Broadcasts a message to the Topic's process group subscribers

  Examples

  iex> Topic.broadcast("mytopic", :hello)

  To exclude the broadcaster from receiving the message, use #broadcast_from/3
  """
  def broadcast(name, message) do
    broadcast_from(:global, name, message)
  end

  @doc """
  Broadcasts a message to the Topic's process group subscribers, excluding
  broadcaster from receiving the message it sent out

  Examples

  iex> Topic.broadcast_from(self, "mytopic", :hello)

  """
  def broadcast_from(from_pid, name, message) do
    name
    |> subscribers
    |> Enum.each fn
      pid when pid != from_pid -> send(pid, message)
      _pid ->
    end
  end

  @doc """
  Check if Topic is active. To be active it must be created and have subscribers
  """
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

  defp group(name), do: "#{@pg_prefix}#{name}"
end

