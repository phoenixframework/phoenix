defmodule Phoenix.Config do

  @doc """
  Returns the ExConf configuration module based on the PHOENIX_ENV give
  the "submodule" of the application. The "base" application module
  is checked for the Existing of a BaseModule.Config module.

  Examples

    iex> System.get_env("PHOENIX_ENV")
    "dev"

    iex> Config.for(MyApp.Router)
    MyApp.Config.Dev

    iex> Config.for(MyApp.Controllers.Admin.Users
    MyApp.Config.Dev

  """
  def for(module) do
    [app_module | _] = Module.split(module)

    find_conf(app_module)
  end

  defp find_conf("Phoenix"), do: Phoenix.Config.Fallback
  defp find_conf(app_module) do
    config_module = Module.concat([app_module, "Config"])

    case Code.ensure_loaded config_module do
      {:module, conf} -> conf.env
      _ -> Phoenix.Config.Fallback
    end
  end
end

