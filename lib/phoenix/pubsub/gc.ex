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
  Unsubscribes the pid from the topic synchronously.

    * `gc_server` - The registered server name or pid
    * `pid` - The subscriber pid
    * `topic` - The string topic, for example "users:123"

  ## Examples

      iex> unsubscribe(:gc_server, self, "foo")
      :ok

  """
  def unsubscribe(gc_server, pid, topic) when is_atom(gc_server) do
    GenServer.call(gc_server, {:unsubscribe, pid, topic})
  end

  @doc """
  Force table clean up because the given pid is down asynchronously.

    * `local_server` - The registered server name or pid
    * `pid` - The subscriber pid

  ## Examples

      iex> down(:gc_server, self)
      :ok

  """
  def down(gc_server, pid) when is_atom(gc_server) do
    GenServer.cast(gc_server, {:down, pid})
  end

  def handle_call({:unsubscribe, pid, topic}, _from, state) do
    true = :ets.match_delete(state, {topic, {pid, :_}})
    {:reply, :ok, state}
  end

  def handle_cast({:down, pid}, state) do
    true = :ets.match_delete(state, {:_, {pid, :_}})
    {:noreply, state}
  end
end
