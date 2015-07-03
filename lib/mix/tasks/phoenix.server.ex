defmodule Mix.Tasks.Phoenix.Server do
  use Mix.Task

  @shortdoc "Starts applications and their servers"

  @moduledoc """
  Starts the application by configuring all endpoints servers to run.

  ## Command line options

  This task accepts the same command-line arguments as `app.start`. For additional
  information, refer to the documentation for `Mix.Tasks.App.Start`.

  For example, to run `phoenix.server` without checking dependencies:

    mix phoenix.server --no-deps-check

  """
  def run(args) do
    Application.put_env(:phoenix, :serve_endpoints, true, persistent: true)
    case Mix.Task.run "app.start", args do
      :ok   -> no_halt()
      :noop -> raise """
        Unable to start server. Application already running!

        If you are trying to run multiple mix tasks that also start the app, ie:

            $ mix do ecto.migrate, phoenix.server

        chain the commands instead, ie:

            $ mix ecto.migrate && mix phoenix.server
      """
    end
  end

  defp no_halt do
    unless iex_running?, do: :timer.sleep(:infinity)
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) && IEx.started?
  end
end
