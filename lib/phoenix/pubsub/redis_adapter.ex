defmodule Phoenix.PubSub.RedisAdapter do

  @behaviour Phoenix.PubSub.Adapter

  @pg_prefix "phxrs"

  alias Phoenix.PubSub.RedisServer

  def start_link(opts \\ []) do
    opts = Application.get_env(:phoenix, :pubsub) |> Dict.merge(opts)
    Phoenix.PubSub.RedisSupervisor.start_link(opts)
  end

  def stop do
    GenServer.call(server_pid, :stop)
  end

  def create(topic),
    do: call({:create, namespace_topic(topic)})

  def exists?(topic),
    do: call({:exists?, namespace_topic(topic)})

  def active?(topic),
    do: call({:active?, namespace_topic(topic)})

  def delete(topic),
    do: call({:delete, namespace_topic(topic)})

  def subscribe(pid, topic),
    do: call({:subscribe, pid, namespace_topic(topic)})

  def unsubscribe(pid, topic),
    do: call({:unsubscribe, pid, namespace_topic(topic)})

  def subscribers(topic) do
    case :pg2.get_local_members(namespace_topic(topic)) do
      {:error, {:no_such_group, _}} -> []
      members -> members
    end
  end

  def broadcast(topic, message) do
    broadcast_from(:global, topic, message)
  end

  def broadcast_from(from_pid, topic, message) do
    call({:broadcast, from_pid, topic, message})
  end

  def list do
    :pg2.which_groups |> Enum.filter(&match?({@pg_prefix, _}, &1))
  end

  def namespace_topic(topic), do: {@pg_prefix, topic}

  def server_pid, do: Process.whereis(RedisServer)

  defp call(message) do
    GenServer.call(server_pid, message)
  end
end
