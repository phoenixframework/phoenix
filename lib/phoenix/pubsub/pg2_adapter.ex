defmodule Phoenix.PubSub.PG2Adapter do
  import GenServer, only: [call: 2]

  @moduledoc """
  Handles PubSub subscriptions and garbage collection with node failover

  All PubSub creates, joins, leaves, and deletes are funneled through master
  PubSub Server to prevent race conditions on global :pg2 groups.

  All nodes monitor master `Phoenix.PubSub.PG2Server` and compete for leader in
  the event of a nodedown.


  ## Configuration

  TODO
  """

  @behaviour Phoenix.PubSub.Adapter

  alias Phoenix.PubSub.PG2Server

  def start_link(opts) do
    GenServer.start_link PG2Server, [], name: Dict.fetch!(opts, :name)
  end

  @doc """
  Subscribes the pid to the pg2 group for the topic
  """
  def subscribe(server, pid, topic),
    do: call(server, {:subscribe, pid, topic})

  @doc """
  Unsubscribes the pid from the pg2 group for the topic
  """
  def unsubscribe(server, pid, topic),
    do: call(server, {:unsubscribe, pid, topic})

  @doc """
  Returns lists of subscriber pids of members of pg2 group for topic
  """
  def subscribers(server, topic),
    do: call(server, {:subscribers, topic})

  @doc """
  Broadcasts message on given topic
  """
  def broadcast(server, topic, message),
    do: call(server, {:broadcast, :none, topic, message})

  @doc """
  Broadcasts message to all but sender on given topic
  """
  def broadcast_from(server, from_pid, topic, message),
    do: call(server, {:broadcast, from_pid, topic, message})

  @doc """
  Returns lists of strings of all topics under pg2
  """
  def list(server), do: call(server, :list)
end
