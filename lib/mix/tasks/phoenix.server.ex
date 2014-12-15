defmodule Mix.Tasks.Phoenix.Server do
  use Mix.Task

  @shortdoc "Starts applications and their servers"
  @recursive true

  @moduledoc """
  Starts the application by configuring all endpoints servers to run.
  """
  def run(_args) do
    Application.put_env :phoenix, :serve_endpoints, true
    Mix.Task.run "app.start", []
    no_halt
  end

  defp no_halt do
    unless iex_running?, do: :timer.sleep(:infinity)
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) && IEx.started?
  end
end
