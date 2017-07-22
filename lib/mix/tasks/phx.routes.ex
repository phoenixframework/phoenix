defmodule Mix.Tasks.Phx.Routes do
  use Mix.Task
  alias Phoenix.Router.ConsoleFormatter

  @shortdoc "Prints all routes"

  @moduledoc """
  Prints all routes for the default or a given router.

      $ mix phx.routes
      $ mix phx.routes MyApp.AnotherRouter

  The default router is inflected from the application
  name unless a configuration named `:namespace`
  is set inside your application configuration. For example,
  the configuration:

      config :my_app,
        namespace: My.App

  will exhibit the routes for `My.App.Router` when this
  task is invoked without arguments.

  Umbrella projects do not have a default router and
  therefore always expect a router to be given.
  """

  @doc false
  def run(args, base \\ Mix.Phoenix.base()) do
    Mix.Task.run "compile", args

    args
    |> Enum.at(0)
    |> router(base)
    |> ConsoleFormatter.format()
    |> Mix.shell.info()
  end

  defp router(nil, base) do
    if Mix.Project.umbrella?() do
      Mix.raise "umbrella applications require an explicit router to be given to phx.routes"
    end
    web_router = web_mod(base, "Router")
    old_router = app_mod(base, "Router")

    loaded(web_router) || loaded(old_router) || Mix.raise """
    no router found at #{inspect web_router} or #{inspect old_router}.
    An explicit router module may be given to phx.routes.
    """
  end
  defp router(router_name, _base) do
    arg_router = Module.concat("Elixir", router_name)
    loaded(arg_router) || Mix.raise "the provided router, #{inspect arg_router}, does not exist"
  end

  defp loaded(module), do: Code.ensure_loaded?(module) && module

  defp app_mod(base, name), do: Module.concat([base, name])

  defp web_mod(base, name), do: Module.concat(["#{base}Web", name])
end
