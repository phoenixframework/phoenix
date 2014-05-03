defmodule Phoenix.Topic do
  use GenServer.Behaviour
  alias Phoenix.Topic.Server

  @server Phoenix.Topic.Server

  @pg_prefix "phx:"

  @doc """
  Creates a Topic for pubsub broadcast to subscribers

  name - The String name of the topic

  Examples

  iex> Topic.create("mytopc")
  :ok
  """
  def create(name) do
    :ok = call {:create, group(name)}
  end

  @doc """
  Checks if a given Topic is registered as a process group
  """
  def exists?(name) do
    call {:exists?, group(name)}
  end

  @doc """
  Removes Topic from process group
  """
  def delete(name) do
    call {:delete, group(name)}
  end

  @doc """
  Adds subsriber pid to given Topic process group

  Examples

  iex> Topic.subscribe(self, "mytopic")
  """
  def subscribe(pid, name) do
    :ok = create(name)
    call {:subscribe, pid, group(name)}
  end

  @doc """
  Removes the given subscriber from the Topic's process group

  Examples

  iex> Topic.unsubscribe(self, "mytopic")
  """
  def unsubscribe(pid, name) do
    call {:unsubscribe, pid, group(name)}
  end

  @doc """
  Returns the List of subsriber pids of the Topic's process group

  iex> Topic.subscribers("mytopic")
  []
  iex> Topic.subscribe(self, "mytopic")
  :ok
  iex> Topic.subscribers("mytopic")
  [#PID<0.41.0>]

  """
  def subscribers(name) do
    call {:subscribers, group(name)}
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
  def active?(name) do
    call {:active?, group(name)}
  end

  def list do
    :pg2.which_groups |> Stream.filter(&match?({@pg_prefix, _}, &1))
  end

  def batch_create(count) do
    {microsec, _ } = :timer.tc fn ->
      Enum.each 1..count, fn i -> create("topic#{i}") end
    end

    microsec / 1_000_000
  end

  defp call(message), do: :gen_server.call(Server.leader_pid, message)

  defp group(name), do: {@pg_prefix, name}
end

