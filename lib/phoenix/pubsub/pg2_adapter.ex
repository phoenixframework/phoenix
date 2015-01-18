defmodule Phoenix.PubSub.PG2Adapter do
  alias Phoenix.PubSub.PG2Server

  @moduledoc """
  Handles PubSub subscriptions and garbage collection with node failover

  All PubSub creates, joins, leaves, and deletes are funneled through master
  PubSub Server to prevent race conditions on global :pg2 groups.

  All nodes monitor master `Phoenix.PubSub.PG2Server` and compete for leader in
  the event of a nodedown.


  ## Configuration

  To set a custom garbage collection timer, add the following to your Mix config

      config :phoenix, :pubsub,
        garbage_collect_after_ms: 60_000..120_000

  """

  @pg_prefix :phx

  def start_link(opts \\ []) do
    options = Dict.merge(Application.get_env(:phoenix, :pubsub), opts)
    GenServer.start_link PG2Server, options, []
  end

  def stop do
    GenServer.call(leader_pid, :stop)
  end

  def create(topic),
    do: call({:create, group(topic)})

  def exists?(topic),
    do: call({:exists?, group(topic)})

  def active?(topic),
    do: call({:active?, group(topic)})

  def delete(topic),
    do: call({:delete, group(topic)})

  def subscribe(pid, topic),
    do: call({:subscribe, pid, group(topic)})

  def unsubscribe(pid, topic),
    do: call({:unsubscribe, pid, group(topic)})

  def subscribers(topic) do
    case :pg2.get_members(group(topic)) do
      {:error, {:no_such_group, _}} -> []
      members -> members
    end
  end

  def broadcast(topic, message) do
    broadcast_from(:global, topic, message)
  end

  def broadcast_from(from_pid, topic, message) do
    topic
    |> subscribers
    |> Enum.each fn
      pid when pid != from_pid -> send(pid, message)
      _pid -> :ok
    end
  end

  def list do
    :pg2.which_groups |> Enum.filter(&match?({@pg_prefix, _}, &1))
  end

  def leader_pid, do: :global.whereis_name(PG2Server)

  defp call(message) do
    GenServer.call(leader_pid, message)
  end

  defp group(topic), do: {@pg_prefix, topic}
end
