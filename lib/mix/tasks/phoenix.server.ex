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
  def run(args) do
    Application.put_env(:phoenix, :serve_endpoints, true, persistent: true)
    Mix.Task.run "run", run_args() ++ args
  end

  defp run_args do
    if iex_running?(), do: [], else: ["--no-halt"]
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) and IEx.started?
  end
end
