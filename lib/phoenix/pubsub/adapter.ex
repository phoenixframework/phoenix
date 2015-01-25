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
  Subscribes pid to the topic
  """
  defcallback subscribe(server :: Pid | atom, pid :: Pid, topic :: String.t) :: :ok | {:error, reason :: term}

  @doc """
  Unsubscribes pid from the topic
  """
  defcallback unsubscribe(server :: Pid | atom, pid :: Pid, topic :: String.t) :: :ok | {:error, reason :: term}

  @doc """
  Broadcasts a message on the given topic
  """
  defcallback broadcast(server :: Pid | atom, topic :: String.t, message :: Map.t) :: :ok | {:error, reason :: term}

  @doc """
  Broadcasts a message on the topic, excluding sender from receiving broadcast
  """
  defcallback broadcast_from(server :: Pid | atom, from_pid :: Pid, String.t, message :: Map.t) :: :ok | {:error, reason :: term}
end
