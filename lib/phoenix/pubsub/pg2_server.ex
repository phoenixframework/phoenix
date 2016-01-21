defmodule Phoenix.PubSub.PG2Server do
  @moduledoc false

  use GenServer
  alias Phoenix.PubSub.Local

  def start_link(server_name) do
    GenServer.start_link __MODULE__, server_name, name: server_name
  end

  def broadcast(server_name, pool_size, dest_node, from_pid, topic, msg) do
    case get_members(server_name, dest_node) do
      {:error, {:no_such_group, _}} ->
        {:error, :no_such_group}

      pids when is_list(pids) ->
        Enum.each(pids, fn
          pid when is_pid(pid) and node(pid) == node() ->
            Local.broadcast(server_name, pool_size, from_pid, topic, msg)
          {^server_name, dest_node} when dest_node == node() ->
            Local.broadcast(server_name, pool_size, from_pid, topic, msg)
          pid_or_tuple ->
            send(pid_or_tuple, {:forward_to_local, from_pid, pool_size, topic, msg})
        end)
        :ok
    end
  end

  def init(server_name) do
    pg2_group = pg2_namespace(server_name)
    :ok = :pg2.create(pg2_group)
    :ok = :pg2.join(pg2_group, self)

    {:ok, server_name}
  end

  def handle_info({:forward_to_local, from_pid, pool_size, topic, msg}, name) do
    # The whole broadcast will happen inside the current process
    # but only for messages coming from the distributed system.
    Local.broadcast(name, pool_size, from_pid, topic, msg)
    {:noreply, name}
  end

  defp get_members(server_name, :global) do
    :pg2.get_members(pg2_namespace(server_name))
  end
  defp get_members(server_name, dest_node) do
    [{server_name, dest_node}]
  end

  defp pg2_namespace(server_name), do: {:phx, server_name}
end
