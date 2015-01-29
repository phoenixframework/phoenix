defmodule Phoenix.PubSub.PG2 do
  use GenServer

  @moduledoc """
  PubSub adapter based on `:pg2`
  """

  def start_link(opts) do
    GenServer.start_link __MODULE__, opts, name: Dict.fetch!(opts, :name)
  end

  def init(opts) do
    server_name = opts[:name]
    pg2_namespace = pg2_namespace(server_name)
    {:ok, local_pid} = Phoenix.PubSub.Local.start_link(Module.concat(server_name, Local))
    :ok = :pg2.create(pg2_namespace)
    :ok = :pg2.join(pg2_namespace, self)
    {:ok, %{local_pid: local_pid, namespace: pg2_namespace}}
  end

  defp pg2_namespace(server_name), do: {:phx, server_name}

  def handle_call({:subscribe, pid, topic}, _from, state) do
    {:reply, GenServer.call(state.local_pid, {:subscribe, pid, topic}), state}
  end

  def handle_call({:unsubscribe, pid, topic}, _from, state) do
    {:reply, GenServer.call(state.local_pid, {:unsubscribe, pid, topic}), state}
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
    {:reply, GenServer.call(state.local_pid, {:subscribers, topic}), state}
  end

  def handle_call(:list, _from, state) do
    {:reply, GenServer.call(state.local_pid, :list), state}
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_info({:forward_to_local, from_pid, topic, msg}, state) do
    GenServer.call(state.local_pid, {:broadcast, from_pid, topic, msg})
    {:noreply, state}
  end
end
