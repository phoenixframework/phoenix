defmodule Mix.Tasks.Phoenix.Start do
  use Mix.Task

  @shortdoc "Starts application endpoints/workers"
  @recursive true

  @moduledoc """
  Starts the default endpoints or the given workers.

  Defaults to `MyApp.Endpoint` for standalone projects.

      # start the default Endpoint in the project
      $ mix phoenix.start

      # explicitly start several Endpoints
      $ mix phoenix.start MyApp.Endpoint MyApp.Worker1 MyApp.Worker2

  You can select the endpoints automatically started by phoenix.start when
  its invoked with no arguments by defining a `endpoints:` item in the
  project configuration:

      defmodule MyApp.Mixfile do
        use Mix.Project

        def project do
          [apps_path: "apps",
           deps: deps,
           endpoints: [Some.Endpoint, Another.Endpoint]]
        end

        defp deps do
          []
        end
      end

  ## Umbrella projects

  By default, `phoenix.start` will not start any endpoints in an umbrella
  project. Umbrella projects must either define their endpoints in the top
  level mix file, or pass them specifically on the command line.
  """
  def run(args) do
    Mix.Task.run "app.start", []
    Enum.each(endpoints(args), fn endpoint -> endpoint.start end)
    no_halt
  end

  defp endpoints(args) do
    cond do
      args != [] ->
        Enum.map(args, &Module.concat("Elixir", &1))
      endpoints = Mix.Project.config[:endpoints] ->
        endpoints
      Mix.Project.umbrella? ->
        Mix.raise "No endpoints available. Umbrella applications must add endpoints in the project " <>
                  "configuration or pass them explicitly via command line arguments"
      true ->
        [Mix.Phoenix.endpoint]
    end
  end

  defp no_halt do
    unless iex_running?, do: :timer.sleep(:infinity)
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) && IEx.started?
  end
end
