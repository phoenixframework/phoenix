defmodule Mix.Tasks.Phoenix.Routes do
  use Mix.Task

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

  @doc false
  def run(args, base \\ Mix.Phoenix.base()) do
    IO.puts :stderr, "mix phoenix.routes is deprecated. Use phx.routes instead."
    Mix.Tasks.Phx.Routes.run(args, base)
  end
end
