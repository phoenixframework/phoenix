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
  Creates a topic for pubsub broadcast to subscribers

    * topic_name - The String name of the topic

  ## Examples

      iex> PubSub.create("mytopic")
      :ok

  """
  def create(topic_name) do
    :ok = adapter.create(topic_name)
  end

  @doc """
  Checks if a given topic is registered as a process group
  """
  def exists?(topic_name) do
    adapter.exists?(topic_name)
  end

  @doc """
  Removes topic from process group if inactive

  ## Examples

      iex> PubSub.delete("mytopic")
      :ok
      iex> PubSub.delete("activetopic")
      {:error, :active}

  """
  def delete(topic_name) do
    adapter.delete(topic_name)
  end

  @doc """
  Adds subsriber pid to the given topic

    * pid - The Pid of the subscriber
    * topic_name - The String name of the topic

  ## Examples

      iex> PubSub.subscribe(self, "mytopic")

  """
  def subscribe(pid, topic_name) do
    adapter = adapter()
    :ok = adapter.create(topic_name)
    adapter.subscribe(pid, topic_name)
  end

  @doc """
  Removes the given subscriber from the topic

    * pid - The Pid of the subscriber
    * topic_name - The String name of the topic

  ## Examples

      iex> PubSub.unsubscribe(self, "mytopic")

  """
  def unsubscribe(pid, topic_name) do
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
  def subscribers(topic_name) do
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
  def broadcast(topic_name, message) do
    broadcast_from(:global, topic_name, message)
  end

  @doc """
  Broadcasts a message to the topics's subscribers, excluding
  broadcaster from receiving the message it sent out

    * topic_name - The String name of the topic
    * message - The term to broadcast

  ## Examples

      iex> PubSub.broadcast_from(self, "mytopic", :hello)

  """
  def broadcast_from(from_pid, topic_name, message) do
    adapter.broadcast_from(from_pid, topic_name, message)
  end

  @doc """
  Check if PubSub is active. To be active it must be created and have subscribers
  """
  def active?(topic_name) do
    adapter.active?(topic_name)
  end

  @doc """
  Returns a List of all Phoenix PubSubs from :pg2
  """
  def list do
    adapter.list()
  end

  defp adapter do
    Application.get_env(:phoenix, :pubsub) |> Dict.get(:adapter, Phoenix.PubSub.PG2Adapter)
  end
end
