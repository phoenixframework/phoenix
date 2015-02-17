defmodule Phoenix.PubSub.PG2Server do
  use GenServer
  alias Phoenix.PubSub.Local

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

    :ok = :pg2.create(pg2_namespace)
    :ok = :pg2.join(pg2_namespace, self)

    {:ok, %{local_name: local_name, namespace: pg2_namespace}}
  end

  def handle_call({:subscribe, pid, topic, opts}, _from, state) do
    response = {:perform, {Local, :subscribe, [state.local_name, pid, topic, opts]}}
    {:reply, response, state}
  end

  def handle_call({:unsubscribe, pid, topic}, _from, state) do
    response = {:perform, {Local, :unsubscribe, [state.local_name, pid, topic]}}
    {:reply, response, state}
  end

  def handle_call({:broadcast, from_pid, topic, msg}, _from, state) do
    case :pg2.get_members(state.namespace) do
      {:error, {:no_such_group, _}} ->
        {:stop, :no_such_group, {:error, :no_such_group}, state}

      pids when is_list(pids) ->
        Enum.each(pids, &send(&1, {:forward_to_local, from_pid, topic, msg}))
        {:reply, :ok, state}
    end
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_info({:forward_to_local, from_pid, topic, msg}, state) do
    Local.broadcast(state.local_name, from_pid, topic, msg)
    {:noreply, state}
  end

  defp pg2_namespace(server_name), do: {:phx, server_name}
end
