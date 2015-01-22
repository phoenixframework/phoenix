defmodule Phoenix.PubSub.RedisBroadcaster do
  use GenServer
  require Logger

  @moduledoc """
  Worker for pooled publishes to redis and forwarding received
  redis messages to pg2 subscribers
  """

  @doc """
  Starts the server

  TODO document options
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc false
  def init(opts) do
    Process.flag(:trap_exit, true)
    {:ok, %{status: :disconnected, opts: opts, pid: nil}}
  end

  @doc false
  def terminate(_reason, state) do
    case state do
      %{status: :disconnected} -> :ok
      state ->
        case :eredis_client.stop(state.pid) do
          :ok -> :ok
          err -> {:error, err}
        end
    end
  end

  def handle_info({:EXIT, _pid, {:connection_error, {:connection_error, :econnrefused}}}, state) do
    {:noreply, state}
  end

  @doc """
  Publishes message to redis with lazily established connection
  """
  def handle_call({:publish_to_redis, topic, msg}, _from, %{status: :disconnected, opts: opts} = state) do
    case :eredis.start_link(opts) do
      {:ok, pid}  ->
        handle_publish(topic, msg, %{state | status: :connected, pid: pid})
      {:error, reason} ->
        Logger.error fn -> "#{inspect __MODULE__} unable to connect to redis #{inspect reason}" end
        {:reply, {:error, reason}, state}
    end
  end
  def handle_call({:publish_to_redis, topic, msg}, _from, state) do
    handle_publish(topic, msg, state)
  end

  @doc """
  Decodes binary message and fowards to pg2 subscribers of topic
  """
  def handle_cast({:forward_to_subscribers, my_node_ref, topic, binary_msg}, state) do
    binary_msg
    |> :erlang.binary_to_term
    |> broadcast(Phoenix.PubSub.RedisAdapter.subscribers(topic), my_node_ref)

    {:noreply, state}
  end

  defp broadcast({_version, my_node_ref, from_pid, msg}, subscribers, my_node_ref) do
    Enum.each subscribers, fn
      pid when pid != from_pid -> send(pid, msg)
      _pid -> :ok
    end
    :ok
  end
  defp broadcast({_version, _remote_ref, _from_pid, msg}, subscribers, _my_ref) do
    Enum.each(subscribers, fn pid -> send(pid, msg) end)
    :ok
  end

  defp handle_publish(topic, msg, state) do
    case :eredis.q(state.pid, ["PUBLISH", topic, msg]) do
      {:ok, _}         -> {:reply, :ok, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end
end
