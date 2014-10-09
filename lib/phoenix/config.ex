defmodule Phoenix.Config.Supervisor do
  @moduledoc false
  @name __MODULE__

  def start_link do
    import Supervisor.Spec

    children = [
      worker(Phoenix.Config, [], type: :transient)
    ]

    opts = [strategy: :simple_one_for_one, name: @name]
    Supervisor.start_link(children, opts)
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
  Starts a supervised Phoenix configuration handler.
  """
  def supervise(otp_app, router) do
    Supervisor.start_child(Phoenix.Config.Supervisor, [otp_app, router])
  end

  @doc """
  Starts a linked Phoenix configuration handler.
  """
  def start_link(otp_app, router) do
    GenServer.start_link(__MODULE__, {otp_app, router})
  end

  @doc """
  Stops Phoenix configuration handler for router.
  """
  def stop(router) do
    [__config__: pid] = :ets.lookup(router, :__config__)
    GenServer.call(pid, :stop)
  end

  @doc """
  Loads the router configuration.
  """
  def load(router) do
    config  = Application.get_env(:phoenix, router, [])

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
  Reloads all configuration children.

  It receives a keyword list with changed routers and another
  with removed ones. The changed config are updated while the
  removed ones stop, effectively removing the table.
  """
  def reload(changed, removed) do
    request = {:config_changed, changed, removed}
    Supervisor.which_children(Phoenix.Config.Supervisor)
    |> Enum.map(&Task.async(GenServer, :call, [elem(&1, 1), request]))
    |> Enum.each(&Task.await(&1))
  end

  # Callbacks

  def init({app, module}) do
    :ets.new(module, [:named_table, :protected, read_concurrency: true])
    :ets.insert(module, [__config__: self()])
    update(module, load(module))
    {:ok, {app, module}}
  end

  def handle_call({:config_changed, changed, removed}, _from, {app, module}) do
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
      port: 4000,
      ssl: false,
      host: "localhost",
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

  @moduledoc """
  Handles Mix Config lookup and default values from Application env

  Uses Mix.Config `:phoenix` settings as configuration with `@defaults` fallback

  Each Router requires an `:endpoint` mapping with Router specific options.

  See `@defaults` for a full list of available configuration options.

  ## Example `config.exs`

      use Mix.Config

      config :phoenix, MyApp.Router,
        port: 4000,
        ssl: false,

  """

  @defaults [
    router: [
      port: 4000,
      ssl: false,
      host: "localhost",
      secret_key_base: nil,
      catch_errors: true,
      debug_errors: false,
      error_controller: Phoenix.Controller.ErrorController,
    ],
    template_engines: [
      eex: Phoenix.Template.EExEngine
    ],
    topics: [
      garbage_collect_after_ms: 60_000..300_000
    ]
  ]


  defmodule UndefinedConfigError do
    defexception [:message]
    def exception(msg), do: %UndefinedConfigError{message: inspect(msg)}
  end

  @doc """
  Returns the default configuration value given the path for get_in lookup
  of `:phoenix` Application configuration

  ## Examples

      iex> Config.default([:router, :port])
      :error

  """
  def default(path) do
    get_in(@defaults, path)
  end
  def default!(path) do
    case default(path) do
      nil   -> raise UndefinedConfigError, message: """
        No default configuration found for #{inspect path}
        """
      value -> value
    end
  end

  @doc """
  Returns the Keyword List of configuration given the path for get_in lookup
  of `:phoenix` Application configuration

  ## Examples

      iex> Config.get([:router, :port])
      :info

  """
  def get(path) do
    case get_in(Application.get_all_env(:phoenix), path) do
      nil   -> default(path)
      value -> value
    end
  end

  @doc """
  Returns the Keyword List of configuration given the path for get_in lookup
  of :phoenix Application configuration.

  Raises `UndefinedConfigError` if the value is nil

  ## Examples

      iex> Config.get!([:router, :port])
      :info

      iex(2)> Phoenix.Config.get!([:router, :key_that_does_not_exist])
      ** (Phoenix.Config.UndefinedConfigError) [message: "No configuration found...

  """
  def get!(path) do
    case get(path) do
      nil   -> raise UndefinedConfigError, message: """
        No configuration found for #{inspect path}
        """
      value -> value
    end
  end

  @doc """
  Returns the Keyword List router Configuration, with merged Phoenix defaults

  A get_in path can be supplied to narrow the config lookup

  ## Examples

      iex> Config.router(MyApp.Router)
      [port: 1234, ssl: false, endpoint: Router, ...]

      iex> Config.router(MyApp.Router, [:port])
      1234

  """
  def router(mod) do
    for {key, _value} <- Dict.merge(@defaults[:router], find_router_conf(mod)) do
      {key, router(mod, [key])}
    end
  end
  def router(module, path) do
    case get_in(find_router_conf(module), path) do
      nil   -> default([:router] ++ path)
      value -> value
    end
  end

  @doc """
  Returns the Keyword List router Configuration, with merged Phoenix defaults,
  raises `UndefinedConfigError` if value does not exist. See `router/2` for details.
  """
  def router!(module, path) do
    case router(module, path) do
      nil   -> raise UndefinedConfigError, message: """
        No configuration found for #{module} #{inspect path}
        """
      value -> value
    end
  end

  defp find_router_conf(module) do
    Application.get_env :phoenix, module, @defaults[:router]
  end
end

