defmodule Mix.Tasks.Phoenix.Routes do
  use Mix.Task
  alias Phoenix.Router.ConsoleFormatter

  @shortdoc "Prints all routes"

  @moduledoc """
  Prints all routes for the default or a given router.

      $ mix phoenix.routes
      $ mix phoenix.routes MyApp.AnotherRouter

  The default router is inflected from the application
  name unless a configuration named `:namespace`
  is set inside your application configuration. For example,
  the configuration:

      config :my_app,
        namespace: My.App

  will exhibit the routes for `My.App.Router` when this
  task is invoked without arguments.

  Umbrella projects do not have a default router and
  therefore always expect a router to be given.
  """

  def run(args) do
    Mix.Task.run "compile", args
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
