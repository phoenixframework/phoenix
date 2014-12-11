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

  def run([]) do
    print_routes(Mix.Phoenix.router)
  end

  def run([router]) do
    print_routes(Module.concat("Elixir", router))
  end

  defp print_routes(router) do
    Mix.shell.info ConsoleFormatter.format(router)
  end
end
