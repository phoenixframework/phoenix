defmodule Mix.Tasks.Phx do
  use Mix.Task

  @shortdoc "Prints Phoenix help information"

  @moduledoc """
  Prints Phoenix tasks and their information.

      mix phx

  """

  @doc false
  def run(args) do
    case args do
      [] -> general()
      _ -> Mix.raise "Invalid arguments, expected: mix phx"
    end
  end

  defp general() do
    Application.ensure_all_started(:phoenix)
    Mix.shell.info "Phoenix v#{Application.spec(:phoenix, :vsn)}"
    Mix.shell.info "Productive. Reliable. Fast."
    Mix.shell.info "A productive web framework that does not compromise speed and maintainability."
    Mix.shell.info "\nAvailable tasks:\n"
    Mix.Tasks.Help.run(["--search", "phx."])
  end
end
