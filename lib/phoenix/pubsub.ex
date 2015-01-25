defmodule Phoenix.PubSub do
  use GenServer

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
  Adds subsriber pid to the given topic

    * pid - The Pid of the subscriber
    * topic_name - The String name of the topic

  ## Examples

      iex> PubSub.subscribe(self, "mytopic")

  """
  def subscribe(pid, topic_name, adapter \\ adapter()) do
    adapter.subscribe(pid, topic_name)
  end

  @doc """
  Removes the given subscriber from the topic

    * pid - The Pid of the subscriber
    * topic_name - The String name of the topic

  ## Examples

      iex> PubSub.unsubscribe(self, "mytopic")

  """
  def unsubscribe(pid, topic_name, adapter \\ adapter()) do
    adapter.unsubscribe(pid, topic_name)
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
  def subscribers(topic_name, adapter \\ adapter()) do
    adapter.subscribers(topic_name)
  end

  @doc """
  Broadcasts a message to the topic's subscribers

    * topic_name - The String name of the topic
    * message - The term to broadcast

  ## Examples

      iex> PubSub.broadcast("mytopic", :hello)

  To exclude the broadcaster from receiving the message, use `broadcast_from/3`
  """
  def broadcast(topic_name, message, adapter \\ adapter()) do
    broadcast_from(:none, topic_name, message, adapter)
  end

  @doc """
  Broadcasts a message to the topics's subscribers, excluding
  broadcaster from receiving the message it sent out

    * topic_name - The String name of the topic
    * message - The term to broadcast

  ## Examples

      iex> PubSub.broadcast_from(self, "mytopic", :hello)

  """
  def broadcast_from(from_pid, topic_name, message, adapter \\ adapter()) do
    adapter.broadcast_from(from_pid, topic_name, message)
  end

  @doc """
  Returns a List of all Phoenix PubSubs from :pg2
  """
  def list(adapter \\ adapter()) do
    adapter.list()
  end

  defp adapter do
    Application.get_env(:phoenix, :pubsub) |> Dict.get(:adapter, Phoenix.PubSub.PG2Adapter)
  end
end
