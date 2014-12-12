defmodule Mix.Tasks.Phoenix.Server do
  use Mix.Task

  @shortdoc "Starts the server for the given endpoints"
  @recursive true

  @moduledoc """
  Starts the default endpoints or the given workers.

  Defaults to `MyApp.Endpoint` for standalone projects.

      # Serves the default Endpoint in the project
      $ mix phoenix.server

      # Explicitly serve several Endpoints
      $ mix phoenix.server MyApp.Endpoint MyApp.Worker1 MyApp.Worker2

  You can select the endpoints automatically started by phoenix.server when
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

  By default, `phoenix.server` will not start any endpoints in an umbrella
  project. Umbrella projects must either define their endpoints in the top
  level mix file, or pass them specifically on the command line.
  """
  def run(args) do
    Mix.Task.run "app.start", []
    Enum.each(Mix.Phoenix.endpoints(args), fn endpoint -> endpoint.serve end)
    no_halt
  end

  defp no_halt do
    unless iex_running?, do: :timer.sleep(:infinity)
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) && IEx.started?
  end
end
