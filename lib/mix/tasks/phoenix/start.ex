defmodule Mix.Tasks.Phoenix.Start do
  use Mix.Task

  @shortdoc "Starts Application Workers"
  @recursive true

  @doc """
  Starts default Router Worker
  """
  def run([]) do
    Phoenix.Project.module_root.Router.start
    no_halt
  end

  @doc """
  Starts provided Worker
  """
  def run([worker]) do
    remote_worker = Module.concat("Elixir", worker)
    if Code.ensure_loaded? remote_worker do
      remote_worker.start
    else
      Module.concat(Phoenix.Project.module_root, worker).start
    end
    no_halt
  end

  defp no_halt do
    unless iex_running?, do: :timer.sleep(:infinity)
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) && IEx.started?
  end
end
