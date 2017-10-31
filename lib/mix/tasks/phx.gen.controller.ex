defmodule Mix.Tasks.Phx.Gen.Controller do
  @shortdoc "Generates a Phoenix controller"

  @moduledoc """
  Generates a Phoenix controller.

      mix phx.gen.controller Posts

  Accepts the module name for the controller

  The generated files will contain:

  For a regular application:

    * a controller in lib/my_app_web/controllers
    * a controller_test in test/my_app_web/controllers

  For an umbrella application:

    * a controller in apps/my_app_web/lib/app_name_web/controllers
    * a controller_test in apps/my_app_web/test/my_app_web/controllers
  """
  use Mix.Task

  @doc false
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise "mix phx.gen.controller can only be run inside an application directory"
    end
    [controller_name] = validate_args!(args)
    context_app = Mix.Phoenix.context_app()
    web_prefix = Mix.Phoenix.web_path(context_app)
    test_prefix = Mix.Phoenix.web_test_path(context_app)
    binding = Mix.Phoenix.inflect(controller_name)
    binding = Keyword.put(binding, :module, "#{binding[:web_module]}.#{binding[:scoped]}")

    Mix.Phoenix.check_module_name_availability!(binding[:module] <> "Controller")

    Mix.Phoenix.copy_from paths(), "priv/templates/phx.gen.controller", binding, [
      {:eex, "controller.ex",       Path.join(web_prefix, "controllers/#{binding[:path]}_controller.ex")},
      {:eex, "controller_test.exs", Path.join(test_prefix, "controllers/#{binding[:path]}_controller_test.exs")},
    ]
  end

  @spec raise_with_help() :: no_return()
  defp raise_with_help do
    Mix.raise """
    mix phx.gen.controller expects just the module name:

        mix phx.gen.controller Posts
    """
  end

  defp validate_args!(args) do
    unless length(args) == 1 do
      raise_with_help()
    end
    args
  end

  defp paths do
    [".", :phoenix]
  end
end
