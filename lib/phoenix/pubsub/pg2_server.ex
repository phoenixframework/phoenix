defmodule Phoenix.PubSub.PG2Server do
  @moduledoc false

  use GenServer
  alias Phoenix.PubSub.Local

  def start_link(name, local_name) do
    GenServer.start_link __MODULE__, {name, local_name}, name: name
  end

  def broadcast(name, local_name, from_pid, topic, msg) do
    case :pg2.get_members(pg2_namespace(name)) do
      {:error, {:no_such_group, _}} ->
        {:error, :no_such_group}

      pids when is_list(pids) ->
        Enum.each(pids, fn
          pid when node(pid) == node() ->
            Local.broadcast(local_name, from_pid, topic, msg)
          pid ->
            send(pid, {:forward_to_local, from_pid, topic, msg})
        end)
        :ok
    end
  end

  def init({name, local_name}) do
    pg2_namespace = pg2_namespace(name)
    :ok = :pg2.create(pg2_namespace)
    :ok = :pg2.join(pg2_namespace, self)
    {:ok, local_name}
  end

  def handle_info({:forward_to_local, from_pid, topic, msg}, local_name) do
    # The whole broadcast will happen inside the current process
    # but only for messages coming from the distributed system.
    Local.broadcast(local_name, from_pid, topic, msg)
    {:noreply, local_name}
  end

  defp pg2_namespace(server_name), do: {:phx, server_name}
end
