defmodule Phoenix.PubSub.PG2Server do
  use GenServer

  @moduledoc """
  `Phoenix.PubSub` adapter based on `:pg2`

  See `Phoenix.PubSub.Redis` for details and configuration options.
  """

  def start_link(opts) do
    GenServer.start_link __MODULE__, opts, name: Dict.fetch!(opts, :name)
  end

  def init(opts) do
    server_name   = Keyword.fetch!(opts, :name)
    local_name    = Keyword.fetch!(opts, :local_name)
    pg2_namespace = pg2_namespace(server_name)

    Process.flag(:trap_exit, true)

    :ok = :pg2.create(pg2_namespace)
    :ok = :pg2.join(pg2_namespace, self)

    {:ok, %{local_name: local_name, namespace: pg2_namespace}}
  end

  def handle_call({:subscribe, pid, topic, link}, _from, state) do
    if link, do: Process.link(pid)
    {:reply, GenServer.call(state.local_name, {:subscribe, pid, topic}), state}
  end

  def handle_call({:unsubscribe, pid, topic}, _from, state) do
    {:reply, GenServer.call(state.local_name, {:unsubscribe, pid, topic}), state}
  end

  def handle_call({:broadcast, from_pid, topic, msg}, _from, state) do
    case :pg2.get_members(state.namespace) do
      {:error, {:no_such_group, _}} -> {:stop, :no_global_group, state}
      pids -> pids
       for pid <- pids do
         send(pid, {:forward_to_local, from_pid, topic, msg})
       end
    end

    {:reply, :ok, state}
  end

  def handle_call({:subscribers, topic}, _from, state) do
    {:reply, GenServer.call(state.local_name, {:subscribers, topic}), state}
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_info({:forward_to_local, from_pid, topic, msg}, state) do
    GenServer.call(state.local_name, {:broadcast, from_pid, topic, msg})
    {:noreply, state}
  end

  def handle_info({:EXIT, _linked_pid, _reason}, state) do
    {:noreply, state}
  end

  defp pg2_namespace(server_name), do: {:phx, server_name}
end
