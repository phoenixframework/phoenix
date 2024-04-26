defmodule Phoenix.Config do
  # Handles Phoenix configuration.
  #
  # This module is private to Phoenix and should not be accessed
  # directly. The Phoenix endpoint configuration can be accessed
  # at runtime using the `config/2` function.
  @moduledoc false

  require Logger
  use GenServer

  @doc """
  Starts a Phoenix configuration handler.
  """
  def start_link({module, config, defaults, opts}) do
    permanent = Keyword.keys(defaults)
    GenServer.start_link(__MODULE__, {module, config, permanent}, opts)
  end

  @doc """
  Puts a given key-value pair in config.
  """
  def put(module, key, value) do
    :ets.insert(module, {key, value})
  end

  @doc """
  Adds permanent configuration.

  Permanent configuration is not deleted on hot code reload.
  """
  def permanent(module, key, value) do
    pid = :ets.lookup_element(module, :__config__, 2)
    GenServer.call(pid, {:permanent, key, value})
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
    try do
      :ets.lookup(module, key)
    rescue
      e ->
        case :ets.info(module) do
          :undefined ->
            raise "could not find ets table for endpoint #{inspect(module)}. Make sure your endpoint is started and note you cannot access endpoint functions at compile-time"

          _ ->
            reraise e, __STACKTRACE__
        end
    else
      [{^key, :cache, val}] ->
        val

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
  Reads the configuration for module from the given OTP app.

  Useful to read a particular value at compilation time.
  """
  def from_env(otp_app, module, defaults) do
    config = fetch_config(otp_app, module)

    merge(defaults, config)
  end

  @doc """
  Take 2 keyword lists and merge them recursively.

  Used to merge configuration values into defaults.
  """
  def merge(a, b), do: Keyword.merge(a, b, &merger/3)

  defp fetch_config(otp_app, module) do
    case Application.fetch_env(otp_app, module) do
      {:ok, conf} -> conf
      :error -> []
    end
  end

  defp merger(_k, v1, v2) do
    if Keyword.keyword?(v1) and Keyword.keyword?(v2) do
      Keyword.merge(v1, v2, &merger/3)
    else
      v2
    end
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

  def init({module, config, permanent}) do
    :ets.new(module, [:named_table, :public, read_concurrency: true])
    update(module, config, [])
    :ets.insert(module, {:__config__, self()})
    {:ok, {module, [:__config__ | permanent]}}
  end

  def handle_call({:permanent, key, value}, _from, {module, permanent}) do
    :ets.insert(module, {key, value})
    {:reply, :ok, {module, [key | permanent]}}
  end

  def handle_call({:config_change, changed, removed}, _from, {module, permanent}) do
    cond do
      changed = changed[module] ->
        update(module, changed, permanent)
        {:reply, :ok, {module, permanent}}

      module in removed ->
        {:stop, :normal, :ok, {module, permanent}}

      true ->
        clear_cache(module)
        {:reply, :ok, {module, permanent}}
    end
  end

  defp update(module, config, permanent) do
    old_keys = :ets.select(module, [{{:"$1", :_}, [], [:"$1"]}])
    new_keys = Enum.map(config, &elem(&1, 0))
    Enum.each((old_keys -- new_keys) -- permanent, &:ets.delete(module, &1))
    :ets.insert(module, config)
    clear_cache(module)
  end
end
