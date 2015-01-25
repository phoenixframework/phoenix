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

  alias Phoenix.PubSub.PG2Server

  def start_link(opts \\ []) do
    options = Dict.merge(Application.get_env(:phoenix, :pubsub), opts)
    GenServer.start_link PG2Server, options, name: PG2Server
  end

  @doc """
  Subscribes the pid to the pg2 group for the topic
  """
  def subscribe(pid, topic),
    do: call({:subscribe, pid, topic})

  @doc """
  Unsubscribes the pid from the pg2 group for the topic
  """
  def unsubscribe(pid, topic),
    do: call({:unsubscribe, pid, topic})

  @doc """
  Returns lists of subscriber pids of members of pg2 group for topic
  """
  def subscribers(topic),
    do: call({:subscribers, topic})

  @doc """
  Broadcasts message on given topic
  """
  def broadcast(topic, message),
    do: call({:broadcast, :none, topic, message})

  @doc """
  Broadcasts message to all but sender on given topic
  """
  def broadcast_from(from_pid, topic, message),
    do: call({:broadcast, from_pid, topic, message})

  @doc """
  Returns lists of strings of all topics under pg2
  """
  def list, do: call(:list)

  defp call(message) do
    GenServer.call(Process.whereis(PG2Server), message)
  end
end
