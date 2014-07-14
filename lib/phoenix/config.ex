defmodule Phoenix.Config do

  @defaults [
    router: [port: 4000,
             ssl: false,
             # Full error reports are disabled
             consider_all_requests_local: false],

    plugs: [code_reload: false,
            serve_static_assets: true,
            cookies: false],

    logger: [level: :error]
  ]


  defmodule UndefinedConfigError do
    defexception [:message]
    def exception(msg), do: %UndefinedConfigError{message: inspect(msg)}
  end

  @doc """
  Returns the Keyword List of configuration given the path for get_in lookup
  of :phoenix Application configuration

  Examples

  iex> Config.get([:logger, :level])
  :info
  """
  def get(path) do
    case get_in(Application.get_all_env(:phoenix), path) do
      nil   -> get_in(@defaults, path)
      value -> value
    end
  end

  @doc """
  Returns the Keyword List of configuration given the path for get_in lookup
  of :phoenix Application configuration.

  Raises UndefinedConfigError if the value is nil

  Examples

  iex> Config.get!([:logger, :level])
  :info

  iex(2)> Phoenix.Config.get!([:logger, :key_that_does_not_exist])
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

  Examples

  iex> Config.router(MyApp.Router)
  [port: 1234, ssl: false, endpoint: Router, ...]

  iex> Config.router(MyApp.Router, [:port])
  1234
  """
  def router(module) do
    for {key, _value} <- Dict.merge(@defaults[:router], find_router_conf(module)) do
      {key, router(module, [key])}
    end
  end
  def router(module, path) do
    case get_in(find_router_conf(module), path) do
      nil   -> get_in(@defaults, [:router] ++ path)
      value -> value
    end
  end

  @doc """
  Returns the Keyword List router Configuration, with merged Phoenix defaults,
  raises UndefinedConfigError if value does not exist. See router/2 for details.
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
    router_config = get([:routers]) || []

    case Enum.find(router_config, &(&1[:endpoint] == module)) do
      nil     -> @defaults[:router]
      configs -> configs
    end
  end
end

