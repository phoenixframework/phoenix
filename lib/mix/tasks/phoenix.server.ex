defmodule Mix.Tasks.Phoenix.Server do
  use Mix.Task

  @shortdoc "Starts applications and their servers"

  @moduledoc """
  Starts the application by configuring all endpoints servers to run.

  ## Command line options

  This task accepts the same command-line arguments as `run`.
  For additional information, refer to the documentation for
  `Mix.Tasks.Run`.

  For example, to run `phoenix.server` without checking dependencies:

      mix phoenix.server --no-deps-check

  The `--no-halt` flag is automatically added.
  """

  @doc false
  def run(args) do
    IO.puts :stderr, "mix phoenix.server is deprecated. Use phx.server instead."
    Mix.Tasks.Phx.Server.run(args)
  end
end
