defmodule Phoenix.Config do

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
        code_reload: false,
        cookies: false

  """

  @defaults [
    router: [
      port: 4000,
      ssl: false,
      consider_all_requests_local: false,      # Full error reports are disabled
      code_reload: false,
      static_assets: true,
      parsers: true,
      error_handler: true,
      cookies: false
    ],
    logger: [level: :error],
    template_engines: [
      eex: Phoenix.Template.EExEngine,
      haml: Phoenix.Template.HamlEngine
    ]
  ]


  defmodule UndefinedConfigError do
    defexception [:message]
    def exception(msg), do: %UndefinedConfigError{message: inspect(msg)}
  end

  @doc """
  Returns the Keyword List of configuration given the path for get_in lookup
  of `:phoenix` Application configuration

  ## Examples

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

  Raises `UndefinedConfigError` if the value is nil

  ## Examples

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

  ## Examples

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

