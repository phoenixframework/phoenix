defmodule Mix.Tasks.Phx.Gen.View do
  @shortdoc "Generates a Phoenix view"

  @moduledoc """
  Generates a Phoenix view.

      mix phx.gen.view Pages

  Accepts the module name for the view

  The generated files will contain:

  For a regular application:

    * a view in lib/my_app_web/views

  For an umbrella application:

    * a view in apps/my_app_web/lib/app_name_web/views
  """
  use Mix.Task

  @doc false
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise "mix phx.gen.view can only be run inside an application directory"
    end
    [view_name] = validate_args!(args)
    context_app = Mix.Phoenix.context_app()
    web_prefix = Mix.Phoenix.web_path(context_app)
    binding = Mix.Phoenix.inflect(view_name)
    binding = Keyword.put(binding, :module, "#{binding[:web_module]}.#{binding[:scoped]}")

    Mix.Phoenix.check_module_name_availability!(binding[:module] <> "View")

    Mix.Phoenix.copy_from paths(), "priv/templates/phx.gen.view", binding, [
      {:eex, "view.ex",       Path.join(web_prefix, "views/#{binding[:path]}_view.ex")},
    ]
  end

  @spec raise_with_help() :: no_return()
  defp raise_with_help do
    Mix.raise """
    mix phx.gen.view expects just the module name:

        mix phx.gen.view Pages
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
