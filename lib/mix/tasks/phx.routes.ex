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
  therefore expect a router to be given or specified
  by the following config:

      config :phoenix,
        phx_routes_router: MyApp.Router
  """

  @doc false
  def run(args, base \\ Mix.Phoenix.base()) do
    Mix.Task.run("compile", args)

    {router_mod, opts} =
      case OptionParser.parse(args, switches: [endpoint: :string, router: :string]) do
        {opts, [passed_router], _} -> {router(passed_router, base), opts}
        {opts, [], _} -> {router(opts[:router], base), opts}
      end


    router_mod
    |> ConsoleFormatter.format(endpoint(opts[:endpoint], base))
    |> Mix.shell().info()
  end

  defp endpoint(nil, base) do
    loaded(web_mod(base, "Endpoint"))
  end
  defp endpoint(module, _base) do
    loaded(Module.concat([module]))
  end

  defp router(nil, base) do
    cond do
      router_from_config = router_from_config() ->
        router(router_from_config, base)

      Mix.Project.umbrella?() ->
        Mix.raise("""
        umbrella applications require an explicit router to be given to phx.routes, for example:

            $ mix phx.routes MyAppWeb.Router

        Alternatively, specify a default router for phx.routes by adding this config:

            config :phoenix,
              phx_routes_router: MyApp.Router

        """)

      true ->
        web_router = web_mod(base, "Router")
        old_router = app_mod(base, "Router")

        loaded(web_router) || loaded(old_router) ||
          Mix.raise("""
          no router found at #{inspect(web_router)} or #{inspect(old_router)}.
          An explicit router module may be given to phx.routes, for example:

              $ mix phx.routes MyAppWeb.Router

          Alternatively, specify a default router for phx.routes by adding this config:

              config :phoenix,
                phx_routes_router: MyApp.Router
          """)
    end
  end

  defp router(router_name, _base) do
    arg_router = Module.concat([router_name])
    loaded(arg_router) || Mix.raise "the provided router, #{inspect(arg_router)}, does not exist"
  end

  defp router_from_config do
    Application.get_env(:phoenix, :phx_routes_router, nil)
  end

  defp loaded(module) do
    if Code.ensure_loaded?(module), do: module
  end

  defp app_mod(base, name), do: Module.concat([base, name])

  defp web_mod(base, name), do: Module.concat(["#{base}Web", name])
end
