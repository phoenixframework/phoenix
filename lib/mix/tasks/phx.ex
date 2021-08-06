defmodule Mix.Tasks.Phx do
  use Mix.Task

  @shortdoc "Prints Phoenix help information"

  @moduledoc """
  Prints Phoenix tasks and their information.

      $ mix phx

  To print the Phoenix version, pass `-v` or `--version`, for example:

      $ mix phx --version

  """

  @version Mix.Project.config()[:version]

  @impl true
  @doc false
  def run([version]) when version in ~w(-v --version) do
    Mix.shell().info("Phoenix v#{@version}")
  end

  def run(args) do
    case args do
      [] -> general()
      _ -> Mix.raise "Invalid arguments, expected: mix phx"
    end
  end

  defp general() do
    Application.ensure_all_started(:phoenix)
    Mix.shell().info "Phoenix v#{Application.spec(:phoenix, :vsn)}"
    Mix.shell().info "Peace of mind from prototype to production"
    Mix.shell().info "\n## Options\n"
    Mix.shell().info "-v, --version        # Prints Phoenix version\n"
    Mix.Tasks.Help.run(["--search", "phx."])
  end
end
