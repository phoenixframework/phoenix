defmodule Phoenix.View do
  @moduledoc """
  Serves as the base view for an entire Phoenix application view layer

  Users define `App.Views` and `use Phoenix.View`. The main view:

    * Serves as a base presentation layer for all views and templates
    * Wires up the Template and template path all for all other views
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
      use Phoenix.HTML
      root = Path.join(unquote(templates_root),
                       Phoenix.Template.module_to_template_root(__MODULE__, "View"))
      use Phoenix.Template, root: root
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
    |> encode(template)
  end
  defp render_within(nil, module, template, assigns) do
    template
    |> module.render(assigns)
    |> encode(template)
  end
  defp render_layout(inner_content, layout_mod, layout_tpl, assigns) do
    layout_assigns = Dict.merge(assigns, inner: inner_content)
    layout_mod.render(layout_tpl, layout_assigns)
  end

  defp encode(content, template) do
    if encoder = Phoenix.Template.format_encoder(template) do
      encoder.encode!(content)
    else
      content
    end
  end

  @doc """
  Returns the default String template root path for current mix project
  """
  def default_templates_root do
    Path.join([File.cwd!, "web/templates"])
  end
end

