defmodule Phoenix.CodeReloader.MixListener do
  @moduledoc false

  use GenServer

  @name __MODULE__

  @spec start_link(keyword) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, {}, name: @name)
  end

  @spec started? :: boolean()
  def started? do
    Process.whereis(Phoenix.CodeReloader.MixListener) != nil
  end

  @doc """
  Unloads all modules invalidated by external compilations.

  Only reloads modules from the given apps.
  """
  @spec purge([atom()]) :: :ok
  def purge(apps) do
    GenServer.call(@name, {:purge, apps}, :infinity)
  end

  @impl true
  def init({}) do
    {:ok, %{to_purge: %{}}}
  end

  @impl true
  def handle_call({:purge, apps}, _from, state) do
    for app <- apps, modules = state.to_purge[app] do
      purge_modules(modules)
    end

    {:reply, :ok, %{state | to_purge: %{}}}
  end

  @impl true
  def handle_info({:modules_compiled, info}, state) do
    if info.os_pid == System.pid() do
      # Ignore compilations from ourselves, because the modules are
      # already updated in memory
      {:noreply, state}
    else
      %{changed: changed, removed: removed} = info.modules_diff

      state =
        update_in(state.to_purge[info.app], fn to_purge ->
          to_purge = to_purge || MapSet.new()
          to_purge = Enum.into(changed, to_purge)
          Enum.into(removed, to_purge)
        end)

      {:noreply, state}
    end
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  defp purge_modules(modules) do
    for module <- modules do
      :code.purge(module)
      :code.delete(module)
    end
  end
end
