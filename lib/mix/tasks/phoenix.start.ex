defmodule Mix.Tasks.Phoenix.Start do
  use Mix.Task

  @shortdoc "Starts application endpoints/workers"
  @recursive true

  @moduledoc """
  Starts the default endpoints or the given workers.
  Defaults to `MyApp.Endpoint`.

      $ mix phoenix.start
      $ mix phoenix.start MyApp.Endpoint MyApp.Worker1 MyApp.Worker2

  """
  def run(args) do
    Mix.Task.run "app.start", []
    Enum.each endpoints(args), &(&1.start)
    no_halt
  end

  defp endpoints([]),      do: [Mix.Phoenix.endpoint]
  defp endpoints(workers), do: Enum.map(workers, &Module.concat("Elixir", &1))

  defp no_halt do
    unless iex_running?, do: :timer.sleep(:infinity)
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) && IEx.started?
  end
end
