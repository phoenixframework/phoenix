defmodule Phoenix.View do
  alias Phoenix.Project

  @moduledoc """
  Serves as the base view for an entire Phoenix application view layer

  Users define `App.Views` and `use Phoenix.View`. The main view:

    * Serves as a base presentation layer for all views and templates
    * Wires up the Template.Compiler and template path all for all other views
    * Expects the base view to define a `__using__` macro for other view modules

  ## Examples

      defmodule App.Views do
        defmacro __using__(_options) do
          quote do
            use Phoenix.View, templates_root: unquote(Path.join([__DIR__, "templates"]))
            import unquote(__MODULE__)

            # This block is expanded within all views for aliases, imports, etc
            alias App.Views

            def title, do: "Welcome to Phoenix!"
          end
        end

        # Functions defined here are available to all other views/templates
      end

      defmodule App.PageView
        use App.Views

        def display(something) do
          String.upcase(something)
        end
      end

  """

  defmacro __using__(options \\ []) do
    templates_root = Dict.get(options, :templates_root, default_templates_root)

    quote do
      import unquote(__MODULE__)
      import Phoenix.Html, only: [safe: 1, unsafe: 1]
      path = template_path_from_view_module(__MODULE__, unquote(templates_root))
      use Phoenix.Template.Compiler, path: path
    end
  end

  @doc """
  Finds the template path given view module and template root path

  ## Examples

      iex> Phoenix.View.template_path_from_view_module(MyApp.UserView, "web/templates")
      "web/templates/user"

  """
  def template_path_from_view_module(view_module, templates_root) do
    submodule_path = view_module
    |> Module.split
    |> tl
    |> Enum.map(&Mix.Utils.underscore/1)
    |> Path.join
    |> String.replace(~r/^(.*)(_view)$/, "\\1")

    Path.join(templates_root, submodule_path)
  end

  @doc """
  Returns the default String template root path for current mix project
  """
  def default_templates_root do
    Path.join([Project.root_path, "web/templates"])
  end
end

