defmodule Phoenix.PubSub.Adapter do
  use Behaviour

  @moduledoc """
  Defines the behaviour of a PubSub adapter.

  See `Phoenix.PubSub.PG2Adapter` for an example implementation.
  """

  defcallback start_link(options :: list) :: {:ok, pid} |
                                             :ignore |
                                             {:error, reason :: term}

  defcallback stop() :: :ok | {:error, reason :: term}

  defcallback create(topic :: String.t) :: :ok | {:error, reason :: term}

  defcallback exists?(topic :: String.t) :: true | false | {:error, reason :: term}

  defcallback active?(topic :: String.t) :: true | false | {:error, reason :: term}

  defcallback delete(topic :: String.t) :: :ok | {:error, reason :: term}

  defcallback subscribe(pid :: Pid, topic :: String.t) :: :ok | {:error, reason :: term}

  defcallback unsubscribe(pid :: Pid, topic :: String.t) :: :ok | {:error, reason :: term}

  defcallback subscribers(String.t) :: list | {:error, reason :: term}

  defcallback broadcast(String.t, message :: Map.t) :: :ok | {:error, reason :: term}

  defcallback broadcast_from(from_pid :: Pid, String.t, message :: Map.t) :: :ok | {:error, reason :: term}

  defcallback list() :: list
end
