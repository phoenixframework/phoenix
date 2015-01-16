defmodule Phoenix.PubSub do
  use GenServer
  alias Phoenix.PubSub.Server

  @moduledoc """
  Serves as a Notification and PubSub layer for broad use-cases. Used internally
  by Channels for pubsub broadcast.

  ## Example

      iex> PubSub.subscribe(self, "user:123")
      :ok
      iex> Process.info(self)[:messages]
      []
      iex> PubSub.subscribers("user:123")
      [#PID<0.169.0>]
      iex> PubSub.broadcast "user:123", {:user_update, %{id: 123, name: "Shane"}}
      :ok
      iex> Process.info(self)[:messages]
      {:user_update, %{id: 123, name: "Shane"}}

  """

  @server Phoenix.PubSub.Server

  @pg_prefix :phx

  @doc """
  Creates a topic for pubsub broadcast to subscribers

    * topic_name - The String name of the topic

  ## Examples

      iex> PubSub.create("mytopic")
      :ok

  """
  def create(topic_name) do
    :ok = call {:create, group(topic_name)}
  end

  @doc """
  Checks if a given topic is registered as a process group
  """
  def exists?(topic_name) do
    call {:exists?, group(topic_name)}
  end

  @doc """
  Removes topic from process group if inactive

  ## Examples

      iex> PubSub.delete("mytopic")
      :ok
      iex> PubSub.delete("activetopic")
      {:error, :active}

  """
  def delete(topic_name) do
    call {:delete, group(topic_name)}
  end

  @doc """
  Adds subsriber pid to the given topic

    * pid - The Pid of the subscriber
    * topic_name - The String name of the topic

  ## Examples

      iex> PubSub.subscribe(self, "mytopic")

  """
  def subscribe(pid, topic_name) do
    :ok = create(topic_name)
    call {:subscribe, pid, group(topic_name)}
  end

  @doc """
  Removes the given subscriber from the topic

    * pid - The Pid of the subscriber
    * topic_name - The String name of the topic

  ## Examples

      iex> PubSub.unsubscribe(self, "mytopic")

  """
  def unsubscribe(pid, topic_name) do
    call {:unsubscribe, pid, group(topic_name)}
  end

  @doc """
  Returns the List of subsriber pids for the give topic

  ## Examples

      iex> PubSub.subscribers("mytopic")
      []
      iex> PubSub.subscribe(self, "mytopic")
      :ok
      iex> PubSub.subscribers("mytopic")
      [#PID<0.41.0>]

  """
  def subscribers(topic_name) do
    case :pg2.get_members(group(topic_name)) do
      {:error, {:no_such_group, _}} -> []
      members -> members
    end
  end

  @doc """
  Broadcasts a message to the topic's subscribers

    * topic_name - The String name of the topic
    * message - The term to broadcast

  ## Examples

      iex> PubSub.broadcast("mytopic", :hello)

  To exclude the broadcaster from receiving the message, use `broadcast_from/3`
  """
  def broadcast(topic_name, message) do
    broadcast_from(:global, topic_name, message)
  end

  @doc """
  Broadcasts a message to the topics's subscribers, excluding
  broadcaster from receiving the message it sent out

    * topic_name - The String name of the topic
    * message - The term to broadcast

  ## Examples

      iex> PubSub.broadcast_from(self, "mytopic", :hello)

  """
  def broadcast_from(from_pid, topic_name, message) do
    topic_name
    |> subscribers
    |> Enum.each fn
      pid when pid != from_pid -> send(pid, message)
      _pid ->
    end
  end

  @doc """
  Check if PubSub is active. To be active it must be created and have subscribers
  """
  def active?(topic_name) do
    call {:active?, group(topic_name)}
  end

  @doc """
  Returns a List of all Phoenix PubSubs from :pg2
  """
  def list do
    :pg2.which_groups |> Enum.filter(&match?({@pg_prefix, _}, &1))
  end

  defp call(message), do: GenServer.call(Server.leader_pid, message)

  defp group(topic_name), do: {@pg_prefix, topic_name}
end
