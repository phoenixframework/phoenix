defmodule Mix.Tasks.Phoenix.Routes do
  use Mix.Task
  alias Phoenix.Router.ConsoleFormatter

  @shortdoc "Prints all routes"
  @recursive true

  @moduledoc """
  Prints all routes for the default or a given router.

      $ mix phoenix.router
      $ mix phoenix.router MyApp.AnotherRouter
  """

  def run([]) do
    router = ConsoleFormatter.default_router
    print_routes(router)
  end

  def run([router]) do
    router = Module.concat([router])
    print_routes(router)
  end

  defp print_routes(router) do
    Mix.shell.info ConsoleFormatter.format(router)
  end
end
