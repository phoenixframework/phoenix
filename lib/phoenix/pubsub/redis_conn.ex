defmodule Phoenix.PubSub.RedisConn do
  use GenServer

  @moduledoc """
  The connection pool for the `Phoenix.PubSub.Redis` adapter
  See `Phoenix.PubSub.Redis` for configuration details.
  """

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    Process.flag(:trap_exit, true)
    {:ok, {:disconnected, opts}}
  end

  def handle_call(:eredis, _, {:disconnected, opts}) do
    case :eredis.start_link(opts) do
      {:ok, pid}    -> {:reply, {:ok, pid}, {pid, opts}}
      {:error, err} -> {:reply, {:error, err}, {:disconnected, opts}}
    end
  end

  def handle_call(:eredis, _, {pid, _opts} = state) do
    {:reply, {:ok, pid}, state}
  end

  def handle_info({:EXIT, pid, _}, {pid, opts}) do
    {:noreply, {:disconnected, opts}}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def terminate({:disconnected, _}), do: :ok
  def terminate({pid, _}), do: :eredis_client.stop(pid)
end
