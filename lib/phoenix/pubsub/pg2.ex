defmodule Phoenix.PubSub.PG2 do
  use GenServer

  @moduledoc """
  PubSub adapter based on `:pg2`
  """

  @private_pg2_group {:phx, :global}


  def start_link(opts) do
    GenServer.start_link __MODULE__, [], name: Dict.fetch!(opts, :name)
  end

  def init(_opts) do
    {:ok, local_pid} = Phoenix.PubSub.Local.start_link()
    :ok = :pg2.create(@private_pg2_group)
    :ok = :pg2.join(@private_pg2_group, self)
    {:ok, %{local_pid: local_pid}}
  end

  def handle_call({:subscribe, pid, topic}, _from, state) do
    {:reply, GenServer.call(state.local_pid, {:subscribe, pid, topic}), state}
  end

  def handle_call({:unsubscribe, pid, topic}, _from, state) do
    {:reply, GenServer.call(state.local_pid, {:unsubscribe, pid, topic}), state}
  end

  def handle_call({:broadcast, from_pid, topic, msg}, _from, state) do
    case :pg2.get_members(@private_pg2_group) do
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
