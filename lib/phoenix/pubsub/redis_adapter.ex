defmodule Phoenix.PubSub.RedisAdapter do
  import GenServer, only: [call: 2]

  @behaviour Phoenix.PubSub.Adapter

  def start_link(opts) do
    opts = Application.get_env(:phoenix, :pubsub) |> Dict.merge(opts)
    Phoenix.PubSub.RedisSupervisor.start_link(opts)
  end

  def subscribe(server, pid, topic),
    do: call(server, {:subscribe, pid, topic})

  def unsubscribe(server, pid, topic),
    do: call(server, {:unsubscribe, pid, topic})

  def subscribers(server, topic),
    do: call(server, {:subscribers, topic})

  def broadcast(server, topic, message) do
    broadcast_from(server, :global, topic, message)
  end

  def broadcast_from(server, from_pid, topic, message) do
    call(server, {:broadcast, from_pid, topic, message})
  end

  def list(server), do: call(server, :list)
end
