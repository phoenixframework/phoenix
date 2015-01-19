defmodule Phoenix.PubSub.PG2Adapter do

  @moduledoc """
  Handles PubSub subscriptions and garbage collection with node failover

  All PubSub creates, joins, leaves, and deletes are funneled through master
  PubSub Server to prevent race conditions on global :pg2 groups.

  All nodes monitor master `Phoenix.PubSub.PG2Server` and compete for leader in
  the event of a nodedown.


  ## Configuration

  To set a custom garbage collection timer, add the following to your Mix config

      config :phoenix, :pubsub,
        adapter: Phoenix.PubSub.PG2Adapter,
        garbage_collect_after_ms: 60_000..120_000

  """

  @behaviour Phoenix.PubSub.Adapter
  @pg_prefix :phx

  alias Phoenix.PubSub.PG2Server

  def start_link(opts \\ []) do
    options = Dict.merge(Application.get_env(:phoenix, :pubsub), opts)
    GenServer.start_link PG2Server, options, []
  end

  @doc """
  Stops the leader
  """
  def stop do
    GenServer.call(server_pid, :stop)
  end

  @doc """
  Creates the namespaced pg2 group for topic
  """
  def create(topic),
    do: call({:create, namespace_topic(topic)})


  @doc """
  Checks if pg2 group exists for topic
  """
  def exists?(topic),
    do: call({:exists?, namespace_topic(topic)})

  @doc """
  Checks if pg2 group has any member pids for topic
  """
  def active?(topic),
    do: call({:active?, namespace_topic(topic)})

  @doc """
  Removes the pg2 group for given topic
  """
  def delete(topic),
    do: call({:delete, namespace_topic(topic)})

  @doc """
  Subscribes the pid to the pg2 group for the topic
  """
  def subscribe(pid, topic),
    do: call({:subscribe, pid, namespace_topic(topic)})

  @doc """
  Unsubscribes the pid from the pg2 group for the topic
  """
  def unsubscribe(pid, topic),
    do: call({:unsubscribe, pid, namespace_topic(topic)})

  @doc """
  Returns lists of subscriber pids of members of pg2 group for topic
  """
  def subscribers(topic) do
    case :pg2.get_members(namespace_topic(topic)) do
      {:error, {:no_such_group, _}} -> []
      members -> members
    end
  end

  @doc """
  Broadcasts message on given topic
  """
  def broadcast(topic, message) do
    broadcast_from(:global, topic, message)
  end

  @doc """
  Broadcasts message to all but sender on given topic
  """
  def broadcast_from(from_pid, topic, message) do
    topic
    |> subscribers
    |> Enum.each fn
      pid when pid != from_pid -> send(pid, message)
      _pid -> :ok
    end
  end

  @doc """
  Returns lists of strings of all topics under pg2
  """
  def list do
    :pg2.which_groups |> Enum.filter(&match?({@pg_prefix, _}, &1))
  end

  @doc """
  Returns the pid of the registered pg2 leader
  """
  def server_pid, do: :global.whereis_name(PG2Server)

  def namespace_topic(topic), do: {@pg_prefix, topic}

  defp call(message) do
    GenServer.call(server_pid, message)
  end
end
