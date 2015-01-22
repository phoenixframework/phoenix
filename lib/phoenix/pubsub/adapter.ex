defmodule Phoenix.PubSub.Adapter do
  use Behaviour

  @moduledoc """
  Defines the behaviour of a PubSub adapter.

  See `Phoenix.PubSub.PG2Adapter` for an example implementation.
  """

  @doc """
  Starts the adapter
  """
  defcallback start_link(options :: list) :: {:ok, pid} |
                                             :ignore |
                                             {:error, reason :: term}

  @doc """
  Creates a PubSub group for given topic to hold subscriptions
  """
  defcallback create(topic :: String.t) :: :ok | {:error, reason :: term}

  @doc """
  Delets a PubSub group for the given topic
  """
  defcallback delete(topic :: String.t) :: :ok | {:error, reason :: term}

  @doc """
  Subscribes pid to the topic
  """
  defcallback subscribe(pid :: Pid, topic :: String.t) :: :ok | {:error, reason :: term}

  @doc """
  Unsubscribes pid from the topic
  """
  defcallback unsubscribe(pid :: Pid, topic :: String.t) :: :ok | {:error, reason :: term}

  @doc """
  Broadcasts a message on the given topic
  """
  defcallback broadcast(topic :: String.t, message :: Map.t) :: :ok | {:error, reason :: term}

  @doc """
  Broadcasts a message on the topic, excluding sender from receiving broadcast
  """
  defcallback broadcast_from(from_pid :: Pid, String.t, message :: Map.t) :: :ok | {:error, reason :: term}
end
