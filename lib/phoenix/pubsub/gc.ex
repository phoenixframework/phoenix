defmodule Phoenix.PubSub.GC do
  @moduledoc """
  A garbage collector process that cleans up the table used
  by `Phoenix.PubSub.Local`.
  """

  use GenServer

  @doc """
  Starts the server.

    * `server_name` - The name to register the server under
    * `table_name` - The name of the local table

  """
  def start_link(server_name, local_name) do
    GenServer.start_link(__MODULE__, local_name, name: server_name)
  end

  @doc """
  Force table clean up because the given pid is down asynchronously.

    * `gc_server` - The registered server name or pid
    * `pid` - The subscriber pid

  ## Examples

      iex> down(:gc_server, self)
      :ok

  """
  def down(gc_server, pid) when is_atom(gc_server) do
    GenServer.cast(gc_server, {:down, pid})
  end

  def handle_cast({:down, pid}, state) do
    try do
      local_pids = Module.concat(state, Pids)
      topics = :ets.lookup_element(local_pids, pid, 2)
      for topic <- topics do
        true = :ets.match_delete(state, {topic, {pid, :_}})
      end
      true = :ets.match_delete(local_pids, {pid, :_})
    catch
      :error, :badarg ->
    end

    {:noreply, state}
  end

  def handle_call(_, _from, state) do
    {:reply, :ok, state}
  end
end
