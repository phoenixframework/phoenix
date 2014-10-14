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

  @doc false
  defmacro __using__(options) do
    if root = Keyword.get(options, :root) do
      quote do
        @view_root unquote(root)
        unquote(__base__())
      end
    else
      # TODO: Remove this message once codebases have been upgraded
      raise """
      You are using the old API for Phoenix.View.
      Here is the new view for your application:

          defmodule YOURAPP.View do
            use Phoenix.View, root: "web/templates"

            # Everything in this block is available runs in this
            # module and in other views that use MyApp.View
            using do
              # Import common functionality
              import YOURAPP.I18n
              import YOURAPP.Router.Helpers

              # Use Phoenix.HTML to import all HTML functions (forms, tags, etc)
              use Phoenix.HTML

              # Common aliases
              alias Phoenix.Controller.Flash
            end

            # Functions defined here are available to all other views/templates
          end

      Replace YOURAPP by your actual application module name.
      """
    end
  end

  @doc """
  Implements the `__using__/1` callback for this view.

  This macro expects a block that will be executed in the current
  module and on all modules that use it. For example, the following
  code:

      defmodule MyApp.View do
        use Phoenix.View, root: "web/templates"

        using do
          IO.inspect __MODULE__
        end
      end

      defmodule MyApp.UserView do
        use MyApp.View
      end

  will print both `MyApp.View` and `MyApp.UserView` names. By using
  `MyApp.View`, `MyApp.UserView` will automatically be made a view
  too.
  """
  defmacro using(do: block) do
    {block, __usable__(block)}
  end

  defp __base__ do
    quote do
      import Phoenix.View
      use Phoenix.Template, root:
        Path.join(@view_root, Phoenix.Template.module_to_template_root(__MODULE__, "View"))
    end
  end

  defp __usable__(block) do
    quote location: :keep do
      @doc false
      defmacro __using__(opts) do
        root  = Keyword.get(opts, :root, @view_root)
        base  = unquote(Macro.escape(__base__()))
        block = unquote(Macro.escape(block))
        quote do
          @view_root unquote(root)
          unquote(base)
          unquote(block)
          import unquote(__MODULE__), except: [render: 2]
        end
      end
    end
  end

  @doc """
  Renders template to String

    * module - The View module, ie, MyView
    * template - The String template, ie, "index.html"
    * assigns - The Dictionary of assigns, ie, [title: "Hello!"]

  ## Examples

      View.render(MyView, "index.html", title: "Hello!")
      #=> "<h1>Hello!</h1>"

  ## Layouts

  Template can be rendered within other templates using the `within` option.
  `within` accepts a Tuple, of the form `{LayoutModule, "template.extension"}`

  When the sub template is rendered, the layout template will have an `@inner`
  assign containing the rendered contents of the sub-template. For html
  templates, `@inner` will be passed through `Phoenix.HTML.safe/1` automatically.

  ### Examples

      View.render(MyView, "index.html", within: {LayoutView, "app.html"})
      #=> "<html><h1>Hello!</h1></html>"

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
  end
  defp render_within(nil, module, template, assigns) do
    template
    |> module.render(assigns)
  end
  defp render_layout(inner_content, layout_mod, layout_tpl, assigns) do
    layout_assigns = Dict.merge(assigns, inner: inner_content)
    layout_mod.render(layout_tpl, layout_assigns)
  end

  def render_to_iodata(module, template, assign) do
    render(module, template, assign) |> encode(template)
  end

  defp encode(content, template) do
    if encoder = Phoenix.Template.format_encoder(template) do
      encoder.encode!(content)
    else
      content
    end
  end
end

