defmodule Phoenix.View do
  @moduledoc """
  Defines the view layer of a Phoenix application.

  This module is used to define the application main view, which
  serves as the base for all other views and templates in the
  application.

  The view layer also contains conveniences for rendering templates,
  including support for layours and encoders per format.

  ## Examples

  First, define the main view module:

      defmodule YourApp.View do
        use Phoenix.View, root: "web/templates"

        # Everything in this block is available runs in this
        # module and in other views that use YourApp.View
        using do
          # Import common functionality
          import YourApp.I18n
          import YourApp.Router.Helpers

          # Use Phoenix.HTML to import all HTML functions (forms, tags, etc)
          use Phoenix.HTML
        end

        # Functions defined here are available to all other views/templates
      end

  Once the main view module is defined, we can use it to define each view:

      defmodule YourApp.UserView do
        use YourApp.View
      end

  Because we have defined the template root to be "web/template", `Phoenix.View`
  will automatically load all templates at "web/template/user" and include them
  in the `YourApp.UserView`. For example, imagine we have the template:

      # web/templates/user/index.html.eex
      Hello <%= @name %>

  The `.eex` extension is called a template engine which tells Phoenix how
  to compile the code in the file into actual Elixir source code. After compiled,
  the template can be rendered as:

      Phoenix.View.render(YourApp.UserView, "index.html", name: "John Doe")
      #=> {:safe, "Hello John Doe"}

  We will discuss rendering with detail next.

  ## Rendering

  The main responsability of a view is to render a template.

  A template has a name, which is also contains a format. For example,
  in the previous section we have rendered the "index.html" template:

      Phoenix.View.render(YourApp.UserView, "index.html", name: "John Doe")
      #=> {:safe, "Hello John Doe"}

  When a view renders a template, the result returned is an inner
  representation specific to the template format. In the example above,
  we got: `{:safe, "Hello John Doe"}`. The safe tuple annotates that our
  template is safe and that we don't need to escape its contents because
  all data was already encoded so far. Let's try to inject custom code:

      Phoenix.View.render(YourApp.UserView, "index.html", name: "John<br />Doe")
      #=> {:safe, "Hello John&lt;br /&gt;Doe"}

  This inner representation allows us to render and compose templates easily.
  For example, if you want to render JSON data, we could do so by adding a
  "show.json" entry to `render/2` in our view:

      defmodule YourApp.UserView do
        use YourApp.View

        def render("user.json", %{user: user}) do
          %{name: user.name, address: user.address}
        end
      end

  Notice that, in order to render JSON data, we don't need to explicitly
  return a JSON string! Instead we just return data that is encodable to
  JSON.

  Both JSON and HTML formats will be encoded only when passing the data
  to the controller via the `render_to_iodata/3` function. The
  `render_to_iodata/3` uses the notion of format encoders to convert a
  particular format to its string/iodata representation.

  Phoenix ships with some template engines and format encoders, which
  can be further configured in the Phoenix application. You can read
  more about format encoders in `Phoenix.Template` documentation.
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
    # Add a :context to avoid warnings
    block = Macro.prewalk(block, fn x ->
      Macro.update_meta(x, &Keyword.put(&1, :context, Phoenix.View))
    end)

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
    quote do
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
  Renders a template.

  It expects the view module, the template as a string, and a
  set of assigns.

  Notice this function returns the inner representation of a
  template. If you want the encoded template as a result, use
  `render_to_iodata/3` instead.

  ## Examples

      Phoenix.View.render(YourApp.UserView, "index.html", name: "John Doe")
      #=> {:safe, "Hello John Doe"}

  ## Assigns

  Assigns are meant to be user data that will be available in templates.
  However, there are keys under assigns that are specially handled by
  Phoenix, they are:

    * :within - tells Phoenix to wrap the rendered result in the
      given layout. See next section.

  ## Layouts

  Template can be rendered within other templates using the `:within`
  option. :within` accepts a tuple of the form `{LayoutModule, "template.extension"}`.

  When a template is rendered, the layout template will have an `@inner`
  assign containing the rendered contents of the sub-template. For HTML
  templates, `@inner` will be always marked as safe.

      Phoenix.View.render(YourApp.UserView, "index.html",
                          within: {YourApp.LayoutView, "application.html"})
      #=> {;safe, "<html><h1>Hello!</h1></html>"}

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

