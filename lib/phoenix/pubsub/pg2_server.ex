defmodule Phoenix.PubSub.PG2Server do
  @moduledoc false

  use GenServer
  alias Phoenix.PubSub.Local

  def start_link(name) do
    GenServer.start_link __MODULE__, name, name: name
  end

  def broadcast(name, pool_size, from_pid, topic, msg) do
    case :pg2.get_members(pg2_namespace(name)) do
      {:error, {:no_such_group, _}} ->
        {:error, :no_such_group}

      pids when is_list(pids) ->
        Enum.each(pids, fn
          pid when node(pid) == node() ->
            Local.broadcast(name, pool_size, from_pid, topic, msg)
          pid ->
            send(pid, {:forward_to_local, from_pid, pool_size, topic, msg})
        end)
        :ok
    end
  end

  def init(name) do
    pg2_namespace = pg2_namespace(name)
    :ok = :pg2.create(pg2_namespace)
    :ok = :pg2.join(pg2_namespace, self)
    {:ok, name}
  end

  def handle_info({:forward_to_local, from_pid, pool_size, topic, msg}, name) do
    # The whole broadcast will happen inside the current process
    # but only for messages coming from the distributed system.
    Local.broadcast(name, pool_size, from_pid, topic, msg)
    {:noreply, name}
  end

  defp pg2_namespace(server_name), do: {:phx, server_name}
end
