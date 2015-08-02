defmodule Phoenix.Config do
  # Handles Phoenix configuration.
  #
  # This module is private to Phoenix and should not be accessed
  # directly. The Phoenix endpoint configuration can be accessed
  # at runtime using the `config/2` function.
  @moduledoc false

  use GenServer

  @doc """
  Starts a Phoenix configuration handler.
  """
  def start_link(otp_app, module, defaults, opts \\ []) do
    GenServer.start_link(__MODULE__, {otp_app, module, defaults}, opts)
  end

  @doc """
  Stops Phoenix configuration handler for the module.
  """
  def stop(module) do
    [__config__: pid] = :ets.lookup(module, :__config__)
    GenServer.call(pid, :stop)
  end

  @doc """
  Deep merges the given configuration.
  """
  def merge(config1, config2) do
    Keyword.merge(config1, config2, &merger/3)
  end

  @doc """
  Caches a value in Phoenix configuration handler for the module.

  The given function needs to return a tuple with `:cache` if the
  value should be cached or `:nocache` if the value should not be
  cached because it can be consequently considered stale.

  Notice writes are not serialized to the server, we expect the
  function that generates the cache to be idempotent.
  """
  @spec cache(module, term, (module -> {:cache | :nocache, term})) :: term
  def cache(module, key, fun) do
    case :ets.lookup(module, key) do
      [{^key, :cache, val}] -> val
      [] ->
        case fun.(module) do
          {:cache, val} ->
            :ets.insert(module, {key, :cache, val})
            val
          {:nocache, val} ->
            val
        end
    end
  end

  @doc """
  Clears all cached entries in the endpoint.
  """
  @spec clear_cache(module) :: :ok
  def clear_cache(module) do
    :ets.match_delete(module, {:_, :cache, :_})
    :ok
  end

  @doc """
  Reads the configuration for module from the given otp app.

  Useful to read a particular value at compilation time.
  """
  def from_env(otp_app, module, defaults) do
    config = Application.get_env(otp_app, module, [])
    merge(defaults, config)
  end

  @doc """
  Changes the configuration for the given module.

  It receives a keyword list with changed config and another
  with removed ones. The changed config are updated while the
  removed ones stop the configuration server, effectively removing
  the table.
  """
  def config_change(module, changed, removed) do
    pid = :ets.lookup_element(module, :__config__, 2)
    GenServer.call(pid, {:config_change, changed, removed})
  end

  # Callbacks

  def init({otp_app, module, defaults}) do
    :ets.new(module, [:named_table, :public, read_concurrency: true])
    :ets.insert(module, [__config__: self()])
    update(module, from_env(otp_app, module, defaults))
    {:ok, {module, defaults}}
  end

  def handle_call({:config_change, changed, removed}, _from, {module, defaults}) do
    cond do
      changed = changed[module] ->
        update(module, merge(defaults, changed))
        {:reply, :ok, {module, defaults}}
      module in removed ->
        stop(module, defaults)
      true ->
        {:reply, :ok, {module, defaults}}
    end
  end

  def handle_call(:stop, _from, {module, defaults}) do
    stop(module, defaults)
  end

  # Helpers

  defp merger(_k, v1, v2) do
    if Keyword.keyword?(v1) and Keyword.keyword?(v2) do
      Keyword.merge(v1, v2, &merger/3)
    else
      v2
    end
  end

  defp update(module, config) do
    old_keys = keys(:ets.tab2list(module))
    new_keys = [:__config__|keys(config)]
    Enum.each old_keys -- new_keys, &:ets.delete(module, &1)
    :ets.insert(module, config)
  end

  defp keys(data) do
    Enum.map(data, &elem(&1, 0))
  end

  defp stop(module, defaults) do
    :ets.delete(module)
    {:stop, :normal, :ok, {module, defaults}}
  end
end
