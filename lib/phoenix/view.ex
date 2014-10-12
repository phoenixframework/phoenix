defmodule Phoenix.View do
  alias Phoenix.HTML
  alias Phoenix.Naming

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
      import Phoenix.View.Helpers
      import Phoenix.HTML, only: [safe: 1, unsafe: 1]
      path = Phoenix.View.template_path_from_view_module(__MODULE__, unquote(templates_root))
      use Phoenix.Template.Compiler, path: path
    end
  end

  @doc """
  Renders template to String

    * module - The View module, ie, MyView
    * template - The String template, ie, "index.html"
    * assigns - The Dictionary of assigns, ie, [title: "Hello!"]

  ## Examples

      iex> View.render(MyView, "index.html", title: "Hello!")
      "<h1>Hello!</h1>"

  ## Layouts

  Template can be rendered within other templates using the `within` option.
  `within` accepts a Tuple, of the form `{LayoutModule, "template.extension"}`

  When the sub template is rendered, the layout template will have an `@inner`
  assign containing the rendered contents of the sub-template. For html
  templates, `@inner` will be passed through `Phoenix.HTML.safe/1` automatically.

  ### Examples

      iex> View.render(MyView, "index.html", within: {LayoutView, "app.html"})
      "<html><h1>Hello!</h1></html>"

  """
  def render(module, template, assigns) do
    assigns
    |> Dict.get(:within)
    |> render_within(module, template, assigns)
  end
  defp render_within({layout_mod, layout_tpl}, inner_mod, template, assigns) do
    template
    |> inner_mod.render(assigns)
    |> render_layout(layout_mod, layout_tpl, assigns)
    |> unwrap_rendered_content(Path.extname(template))
  end
  defp render_within(nil, module, template, assigns) do
    template
    |> module.render(assigns)
    |> unwrap_rendered_content(Path.extname(template))
  end
  defp render_layout(inner_content, layout_mod, layout_tpl, assigns) do
    layout_assigns = Dict.merge(assigns, inner: inner_content)
    layout_mod.render(layout_tpl, layout_assigns)
  end

  @doc """
  Unwraps rendered String content within extension specific structure

  ## Examples

      iex> View.unwrap_rendered_content({:safe, "<h1>Hello!</h1>"}, ".html")
      "<h1>Hello!</h1>"
      iex> View.unwrap_rendered_content("Hello!", ".txt")
      "Hello!"

  """
  def unwrap_rendered_content(content, ".html"), do: HTML.unsafe(content)
  def unwrap_rendered_content(content, _ext), do: content

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
    |> Enum.map(&Naming.underscore/1)
    |> Path.join
    |> String.replace(~r/^(.*)(_view)$/, "\\1")

    Path.join(templates_root, submodule_path)
  end

  @doc """
  Returns the default String template root path for current mix project
  """
  def default_templates_root do
    Path.join([File.cwd!, "web/templates"])
  end
end

