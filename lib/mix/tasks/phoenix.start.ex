defmodule Mix.Tasks.Phoenix.Start do
  use Mix.Task

  @shortdoc "Starts application workers"

  @moduledoc """
  Starts one or more routers in the project. Defaults to `MyApp.Router` 
  for standalone projects.

      # start the default router(s) in the project
      $ mix phoenix.start

      # explicitly start several routers
      $ mix phoenix.start Some.Router Another.Router

  You can select the routers automatically started by phoenix.start when 
  its invoked with no arguments by defining a `routers:` item in the 
  project configuration:

      defmodule MyApp.Mixfile do
          use Mix.Project

          def project do
            [apps_path: "apps",
             deps: deps,
             routers: [Some.Router, Another.Router]]
          end

          defp deps do
            []
          end 
      end

  ## Umbrella projects
  By default, `phoenix.start` will not start any routers in an umbrella 
  project. Umbrella projects must either define their routers in the top
  level mix file, or pass them specifically on the command line.
  """
  def run(routers \\ []) do
    if routers == [] do 
      routers = Keyword.get :Mix.Project.config, :routers, []
    end

    if Mix.Project.umbrella? do
      start_all_apps
    else
      Mix.Task.run "app.start", []
      if routers == [] do routers = [Mix.Phoenix.router.start] end
    end

    if routers != [] do
      for r <- routers do 
        Module.concat("Elixir", r).start
      end
      no_halt
    end
  end

  defp no_halt do
    unless iex_running?, do: :timer.sleep(:infinity)
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) && IEx.started?
  end

  defp start_all_apps do
    config = Mix.Project.deps_config |> Keyword.delete(:deps_path)
    for %Mix.Dep{app: app, opts: opts} <- Mix.Dep.Umbrella.loaded do
      Mix.Project.in_project(app, opts[:path], config, 
        fn _ -> Mix.Task.run "app.start", [] end)
    end  
  end
end
