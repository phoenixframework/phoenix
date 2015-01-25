defmodule Phoenix.PubSub.RedisAdapter do

  @behaviour Phoenix.PubSub.Adapter

  def start_link(opts \\ []) do
    opts = Application.get_env(:phoenix, :pubsub) |> Dict.merge(opts)
    Phoenix.PubSub.RedisSupervisor.start_link(opts)
  end

  def subscribe(pid, topic),
    do: call({:subscribe, pid, topic})

  def unsubscribe(pid, topic),
    do: call({:unsubscribe, pid, topic})

  def subscribers(topic),
    do: call({:subscribers, topic})

  def broadcast(topic, message) do
    broadcast_from(:global, topic, message)
  end

  def broadcast_from(from_pid, topic, message) do
    call({:broadcast, from_pid, topic, message})
  end

  def list, do: call(:list)

  defp call(message) do
    GenServer.call(Phoenix.PubSub.RedisServer, message)
  end
end
