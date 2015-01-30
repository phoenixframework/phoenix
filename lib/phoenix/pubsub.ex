defmodule Phoenix.PubSub do
  import GenServer, only: [call: 2]

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

  @doc false
  # Returns list of all topics under local server, for debug and perf tuning
  def list(server_name) do
    GenServer.call(Module.concat(server_name, Local), :list)
  end
end
