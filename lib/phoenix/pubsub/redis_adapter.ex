
defmodule Phoenix.PubSub.RedisAdapter do

  @behaviour Phoenix.PubSub.Adapter

  alias Phoenix.PubSub.RedisServer

  def start_link(opts \\ []) do
    opts = Application.get_env(:phoenix, :pubsub) |> Dict.merge(opts)
    Phoenix.PubSub.RedisSupervisor.start_link(opts)
  end

  def stop do
    GenServer.call(server_pid, :stop)
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

  def subscribers(topic),
    do: call({:subscribers, group(topic)})

  def broadcast(topic, message) do
    broadcast_from(:global, topic, message)
  end

  def broadcast_from(from_pid, topic, message) do
    call({:broadcast, from_pid, group(topic), message})
  end

  def list do
    call(:list)
  end

  def server_pid, do: Process.whereis(RedisServer)

  defp call(message) do
    GenServer.call(server_pid, message)
  end

  defp group(topic), do: "phx:#{topic}"
end
