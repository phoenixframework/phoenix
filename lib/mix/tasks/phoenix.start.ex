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
  def run(args) do
    Mix.Task.run "app.start", []
    Enum.map routers(args), &(&1.start)
    no_halt
  end

  defp routers([]) do
    rs = Keyword.get :Mix.Project.config, :routers, []
    if rs == [] and not Mix.Project.umbrella? do
      rs = [Mix.Phoenix.router]
    end
    routers(rs)
  end

  defp routers(args) do
    for r <- args, do: Module.concat("Elixir", r)
  end

  defp no_halt do
    unless iex_running?, do: :timer.sleep(:infinity)
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) && IEx.started?
  end
end
