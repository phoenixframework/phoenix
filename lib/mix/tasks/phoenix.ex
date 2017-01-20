defmodule Mix.Tasks.Phoenix do
  use Mix.Task

  @shortdoc "Prints Phoenix help information"

  @moduledoc """
  Prints Phoenix tasks and their information.

    mix phoenix

  """

  @doc false
  def run(args) do
    {_opts, args, _} = OptionParser.parse(args)

    case args do
      [] -> help()
      _  ->
        Mix.raise "Invalid arguments, expected: mix phoenix"
    end
  end

  defp help() do
    Application.ensure_all_started(:phoenix)
    Mix.shell.info "Phoenix v#{Application.spec(:phoenix, :vsn)}"
    Mix.shell.info "A productive web framework that does not compromise speed and maintainability."
    Mix.shell.info "\nAvailable tasks:\n"
    Mix.Tasks.Help.run(["--search", "phoenix."])
  end
end
