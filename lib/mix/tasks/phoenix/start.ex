defmodule Mix.Tasks.Phoenix.Start do
  use Mix.Task

  @shortdoc "Starts application workers"
  @recursive true

  @moduledoc """
  Starts the router or a given worker

      $ mix phoenix.router
      $ mix phoenix.router MyApp.AnotherRouter

  """
  def run([]) do
    Mix.Task.run "app.start", []
    Mix.Phoenix.router.start
    no_halt
  end

  def run([worker]) do
    Mix.Task.run "app.start", []
    remote_worker = Module.concat("Elixir", worker)
    remote_worker.start
    no_halt
  end

  defp no_halt do
    unless iex_running?, do: :timer.sleep(:infinity)
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) && IEx.started?
  end
end
