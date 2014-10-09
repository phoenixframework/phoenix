defmodule Phoenix.Config.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    children = [
      worker(Phoenix.Config, [], type: :transient)
    ]

    supervise children, strategy: :simple_one_for_one
  end
end

defmodule Phoenix.Config do
  # Handles router configuration.
  #
  # This module is private to Phoenix and should not be accessed
  # directly. The Phoenix Router configuration can be accessed at
  # runtime using the `config/2` function or at compilation time via
  # the `@config` attribute.
  @moduledoc false

  use GenServer

  @doc """
  Returns the compile router configuration for compilation time.
  """
  def compile_time(router) do
    config = Application.get_env(:phoenix, router, [])

    otp_app = cond do
      config[:otp_app] ->
        config[:otp_app]
      Code.ensure_loaded?(Mix.Project) && Mix.Project.config[:app] ->
        Mix.Project.config[:app]
      true ->
        raise "please set :otp_app config for #{inspect router}"
    end

    with_defaults(config, otp_app)
  end

  @doc """
  Starts a supervised Phoenix configuration handler for runtime.

  Data is accessed by the router via ETS.
  """
  def runtime(otp_app, router) do
    Supervisor.start_child(Phoenix.Config.Supervisor, [otp_app, router])
  end

  ## GenServer API

  @doc """
  Starts a linked Phoenix configuration handler.
  """
  def start_link(otp_app, router) do
    GenServer.start_link(__MODULE__, {otp_app, router})
  end

  @doc """
  Stops Phoenix configuration handler for the router.
  """
  def stop(router) do
    [__config__: pid] = :ets.lookup(router, :__config__)
    GenServer.call(pid, :stop)
  end

  @doc """
  Caches a value in Phoenix configuration handler for the router.

  Notice writes are not serialized to the server, we expect the
  function that generates the cache to be idempotent.
  """
  def cache(router, key, fun) do
    case :ets.lookup(router, key) do
      [{^key, val}] -> val
      [] ->
        val = fun.(router)
        store(router, [{key, val}])
        val
    end
  end

  @doc """
  Stores the given keywords in the Phoenix configuration handler for the router.
  """
  def store(router, pairs) do
    [__config__: pid] = :ets.lookup(router, :__config__)
    GenServer.call(pid, {:store, pairs})
  end

  @doc """
  Reloads all children.

  It receives a keyword list with changed routers and another
  with removed ones. The changed config are updated while the
  removed ones stop, effectively removing the table.
  """
  def reload(changed, removed) do
    request = {:config_change, changed, removed}
    Supervisor.which_children(Phoenix.Config.Supervisor)
    |> Enum.map(&Task.async(GenServer, :call, [elem(&1, 1), request]))
    |> Enum.each(&Task.await(&1))
  end

  # Callbacks

  def init({app, module}) do
    :ets.new(module, [:named_table, :protected, read_concurrency: true])
    :ets.insert(module, [__config__: self()])
    config = Application.get_env(:phoenix, module, [])
    update(module, with_defaults(config, app))
    {:ok, {app, module}}
  end

  def handle_call({:store, config}, _from, {app, module}) do
    :ets.insert(module, config)
    {:reply, :ok, {app, module}}
  end

  def handle_call({:config_change, changed, removed}, _from, {app, module}) do
    cond do
      changed = changed[module] ->
        update(module, with_defaults(changed, app))
        {:reply, :ok, {app, module}}
      module in removed ->
        stop(app, module)
      true ->
        {:reply, :ok, {app, module}}
    end
  end

  def handle_call(:stop, _from, {app, module}) do
    stop(app, module)
  end

  # Helpers

  defp with_defaults(config, otp_app) do
    defaults = [
      otp_app: otp_app,

      # Compile-time config
      parsers: [parsers: [:urlencoded, :multipart, :json],
                 accept: ["*/*"], json_decoder: Poison],
      static: [at: "/"],
      session: false,

      # Runtime config
      url: [host: "localhost"],
      http: [port: 4000, otp_app: otp_app],
      https: [port: 4040, otp_app: otp_app],
      secret_key_base: nil,
      catch_errors: true,
      debug_errors: false,
      error_controller: Phoenix.Controller.ErrorController
    ]

    Keyword.merge(defaults, config, &merger/3)
  end

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

  defp stop(app, module) do
    :ets.delete(module)
    {:stop, :normal, :ok, {app, module}}
  end
end
