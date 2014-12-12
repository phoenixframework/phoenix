defmodule Mix.Tasks.Phoenix.Routes do
  use Mix.Task
  alias Phoenix.Router.ConsoleFormatter

  @shortdoc "Prints all routes"

  @moduledoc """
  Prints all routes for the default or a given router.

      $ mix phoenix.routes
      $ mix phoenix.routes MyApp.AnotherRouter

  Umbrella projects do not have a default router and
  therefore always expect a router to be given.
  """

  def run(args) do
    Mix.shell.info ConsoleFormatter.format(router(args))
  end

  defp router(args) do
    cond do
      router = Enum.at(args, 0) ->
        Module.concat("Elixir", router)
      Mix.Project.umbrella? ->
        Mix.raise "Umbrella applications require an explicit router to be given to phoenix.routes"
      true ->
        Module.concat(Mix.Phoenix.base(), "Router")
    end
  end
end
