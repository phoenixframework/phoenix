defmodule Phoenix.View do
  @moduledoc """
  Defines the view layer of a Phoenix application.

  This module is used to define the application's main view, which
  serves as the base for all other views and templates.

  The view layer also contains conveniences for rendering templates,
  including support for layouts and encoders per format.

  ## Examples

  Phoenix defines the view template at `lib/your_app_web.ex`:

      defmodule YourAppWeb do
        # ...

        def view do
          quote do
            use Phoenix.View, root: "lib/your_app_web/templates", namespace: "web"

            # Import convenience functions from controllers
            import Phoenix.Controller, only: [get_flash: 1, get_flash: 2, view_module: 1]

            # Use all HTML functionality (forms, tags, etc)
            use Phoenix.HTML

            import YourAppWeb.ErrorHelpers
            import YourAppWeb.Gettext

            # Alias the Helpers module as Routes
            alias  YourAppWeb.Router.Helpers, as: Routes
          end
        end

        # ...
      end

  You can use the definition above to define any view in your application:

      defmodule YourApp.UserView do
        use YourAppWeb, :view
      end

  Because we have defined the template root to be "lib/your_app_web/templates", `Phoenix.View`
  will automatically load all templates at "your_app_web/templates/user" and include them
  in the `YourApp.UserView`. For example, imagine we have the template:

      # your_app_web/templates/user/index.html.eex
      Hello <%= @name %>

  The `.eex` extension maps to a template engine which tells Phoenix how
  to compile the code in the file into Elixir source code. After it is
  compiled, the template can be rendered as:

      Phoenix.View.render(YourApp.UserView, "index.html", name: "John Doe")
      #=> {:safe, "Hello John Doe"}

  ## Rendering

  The main responsibility of a view is to render a template.

  A template has a name, which also contains a format. For example,
  in the previous section we have rendered the "index.html" template:

      Phoenix.View.render(YourApp.UserView, "index.html", name: "John Doe")
      #=> {:safe, "Hello John Doe"}

  When a view renders a template, the result returned is an inner
  representation specific to the template format. In the example above,
  we got: `{:safe, "Hello John Doe"}`. The safe tuple annotates that our
  template is safe and that we don't need to escape its contents because
  all data has already been encoded. Let's try to inject custom code:

      Phoenix.View.render(YourApp.UserView, "index.html", name: "John<br/>Doe")
      #=> {:safe, "Hello John&lt;br/&gt;Doe"}

  This inner representation allows us to render and compose templates easily.
  For example, if you want to render JSON data, we could do so by adding a
  "show.json" entry to `render/2` in our view:

      defmodule YourApp.UserView do
        use YourApp.View

        def render("show.json", %{user: user}) do
          %{name: user.name, address: user.address}
        end
      end

  Notice that in order to render JSON data, we don't need to explicitly
  return a JSON string! Instead, we just return data that is encodable to
  JSON.

  Both JSON and HTML formats will be encoded only when passing the data
  to the controller via the `render_to_iodata/3` function. The
  `render_to_iodata/3` function uses the notion of format encoders to convert a
  particular format to its string/iodata representation.

  Phoenix ships with some template engines and format encoders, which
  can be further configured in the Phoenix application. You can read
  more about format encoders in `Phoenix.Template` documentation.
  """
  alias Phoenix.{Template}

  @doc """
  When used, defines the current module as a main view module.

  ## Options

    * `:root` - the template root to find templates
    * `:path` - the optional path to search for templates within the `:root`.
      Defaults to the underscored view module name. A blank string may
      be provided to use the `:root` path directly as the template lookup path
    * `:namespace` - the namespace to consider when calculating view paths
    * `:pattern` - the wildcard pattern to apply to the root
      when finding templates. Default `"*"`

  The `:root` option is required while the `:namespace` defaults to the
  first nesting in the module name. For instance, both `MyApp.UserView`
  and `MyApp.Admin.UserView` have namespace `MyApp`.

  The `:namespace` and `:path` options are used to calculate template
  lookup paths. For example, if you are in `MyApp.UserView` and the
  namespace is `MyApp`, templates are expected at `Path.join(root, "user")`.
  On the other hand, if the view is `MyApp.Admin.UserView`,
  the path will be `Path.join(root, "admin/user")` and so on. For
  explicit root path locations, the `:path` option can be provided instead.
  The `:root` and `:path` are joined to form the final lookup path.
  A blank string may be provided to use the `:root` path directly as the
  template lookup path.

  Setting the namespace to `MyApp.Admin` in the second example will force
  the template to also be looked up at `Path.join(root, "user")`.
  """
  defmacro __using__(opts) do
    %{module: module} = __CALLER__

    if Module.get_attribute(module, :view_resource) do
      raise ArgumentError,
            "use Phoenix.View is being called twice in the module #{module}. " <>
              "Make sure to call it only once per module"
    else
      view_resource = String.to_atom(Phoenix.Naming.resource_name(module, "View"))
      Module.put_attribute(module, :view_resource, view_resource)
    end

    quote do
      import Phoenix.View
      use Phoenix.Template, Phoenix.View.__template_options__(__MODULE__, unquote(opts))

      @before_compile Phoenix.View
      @view_resource String.to_atom(Phoenix.Naming.resource_name(__MODULE__, "View"))

      @doc """
      Renders the given template locally.
      """
      def render(template, assigns \\ %{})

      def render(module, template) when is_atom(module) do
        Phoenix.View.render(module, template, %{})
      end

      def render(template, _assigns) when not is_binary(template) do
        raise ArgumentError, "render/2 expects template to be a string, got: #{inspect template}"
      end

      def render(template, assigns) when not is_map(assigns) do
        render(template, Enum.into(assigns, %{}))
      end

      @doc "The resource name, as an atom, for this view"
      def __resource__, do: @view_resource
    end
  end


  @anno (if :erlang.system_info(:otp_release) >= '19' do
    [generated: true]
  else
    [line: -1]
  end)

  @doc false
  defmacro __before_compile__(_env) do
    # We are using @anno because we don't want warnings coming from
    # render/2 to be reported in case the user has defined a catch-all
    # render/2 clause.
    quote @anno do
      # Catch-all clause for rendering.
      def render(template, assigns) do
        render_template(template, assigns)
      end
    end
  end

  @doc """
  Renders a template.

  It expects the view module, the template as a string, and a
  set of assigns.

  Notice that this function returns the inner representation of a
  template. If you want the encoded template as a result, use
  `render_to_iodata/3` instead.

  ## Examples

      Phoenix.View.render(YourApp.UserView, "index.html", name: "John Doe")
      #=> {:safe, "Hello John Doe"}

  ## Assigns

  Assigns are meant to be user data that will be available in templates.
  However, there are keys under assigns that are specially handled by
  Phoenix, they are:

    * `:layout` - tells Phoenix to wrap the rendered result in the
      given layout. See next section

  The following assigns are reserved, and cannot be set directly:

    * `@view_module` - The view module being rendered
    * `@view_template` - The `@view_module`'s template being rendered

  ## Layouts

  Templates can be rendered within other templates using the `:layout`
  option. `:layout` accepts a tuple of the form
  `{LayoutModule, "template.extension"}`.

  To render the template within the layout, simply call `render/3`
  using the `@view_module` and `@view_template` assigns:

      <%= render(@view_module, @view_template, assigns) %>

  """
  def render(module, template, assigns) do
    assigns
    |> to_map()
    |> Map.pop(:layout, false)
    |> render_within(module, template)
  end

  defp render_within({false, assigns}, module, template) do
    assigns = Map.merge(assigns, %{view_module: module,
                                   view_template: template})
    module.render(template, assigns)
  end

  defp render_within({layout, assigns}, inner_mod, inner_tpl) do
    assigns = Map.merge(assigns, %{view_module: inner_mod, view_template: inner_tpl})
    render_layout(layout, assigns)
  end

  defp render_layout({layout_mod, layout_tpl}, assigns)
       when is_atom(layout_mod) and is_binary(layout_tpl) do
    layout_mod.render(layout_tpl, assigns)
  end

  defp render_layout(layout, _assigns) do
    raise ArgumentError, """
    invalid value for reserved key :layout in View.render/3 assigns

    :layout accepts a tuple of the form {LayoutModule, "template.extension"}

    got: #{inspect(layout)}
    """
  end

  @doc """
  Renders a template only if it exists.

  Same as `render/3`, but returns `nil` instead of raising.
  Useful for dynamically rendering templates in the layout that may or
  may not be implemented by the `@view_module` view.

  ## Examples

  Consider the case where the application layout allows views to dynamically
  render a section of script tags in the head of the document. Some views
  may wish to inject certain scripts, while others will not.

      <head>
        <%= render_existing @view_module, "scripts.html", assigns %>
      </head>

  Then the module for the `@view_module` view can decide to provide scripts with
  either a precompiled template, or by implementing the function directly, ie:

      def render("scripts.html", _assigns) do
        ~E(<script src="file.js"></script>)
      end

  To use a precompiled template, create a `scripts.html.eex` file in the `templates`
  directory for the corresponding view you want it to render for. For example,
  for the `UserView`, create the `scripts.html.eex` file at `your_app_web/templates/user/`.

  ## Rendering based on controller template

  In some cases, you might need to render based on the template.
  For these cases, `@view_template` can pair with
  `render_existing/3` for per-template based content, ie:

      <head>
        <%= render_existing @view_module, "scripts." <> @view_template, assigns %>
      </head>

      def render("scripts.show.html", _assigns) do
        ~E(<script src="file.js"></script>)
      end
      def render("scripts.index.html", _assigns) do
        ~E(<script src="file.js"></script>)
      end

  """
  def render_existing(module, template, assigns \\ []) do
    render(module, template, put_in(assigns[:__phx_render_existing__], {module, template}))
  end

  @doc """
  Renders a collection.

  A collection is any enumerable of structs. This function
  returns the rendered collection in a list:

      render_many users, UserView, "show.html"

  is roughly equivalent to:

      Enum.map(users, fn user ->
        render(UserView, "show.html", user: user)
      end)

  The underlying user is passed to the view and template as `:user`,
  which is inferred from the view name. The name of the key
  in assigns can be customized with the `:as` option:

      render_many users, UserView, "show.html", as: :data

  is roughly equivalent to:

      Enum.map(users, fn user ->
        render(UserView, "show.html", data: user)
      end)

  """
  def render_many(collection, view, template, assigns \\ %{}) do
    assigns = to_map(assigns)
    Enum.map(collection, fn resource ->
      render view, template, assign_resource(assigns, view, resource)
    end)
  end

  @doc """
  Renders a single item if not nil.

  The following:

      render_one user, UserView, "show.html"

  is roughly equivalent to:

      if user != nil do
        render(UserView, "show.html", user: user)
      end

  The underlying user is passed to the view and template as
  `:user`, which is inflected from the view name. The name
  of the key in assigns can be customized with the `:as` option:

      render_one user, UserView, "show.html", as: :data

  is roughly equivalent to:

      if user != nil do
        render(UserView, "show.html", data: user)
      end

  """
  def render_one(resource, view, template, assigns \\ %{})
  def render_one(nil, _view, _template, _assigns), do: nil
  def render_one(resource, view, template, assigns) do
    assigns = to_map(assigns)
    render view, template, assign_resource(assigns, view, resource)
  end

  defp to_map(assigns) when is_map(assigns), do: assigns
  defp to_map(assigns) when is_list(assigns), do: :maps.from_list(assigns)

  defp assign_resource(assigns, view, resource) do
    as = Map.get(assigns, :as) || view.__resource__
    Map.put(assigns, as, resource)
  end

  @doc """
  Renders the template and returns iodata.
  """
  def render_to_iodata(module, template, assign) do
    render(module, template, assign) |> encode(template)
  end

  @doc """
  Renders the template and returns a string.
  """
  def render_to_string(module, template, assign) do
    render_to_iodata(module, template, assign) |> IO.iodata_to_binary
  end

  defp encode(content, template) do
    if encoder = Template.format_encoder(template) do
      encoder.encode_to_iodata!(content)
    else
      content
    end
  end

  @doc false
  def __template_options__(module, opts) do
    root = opts[:root] || raise(ArgumentError, "expected :root to be given as an option")
    path = opts[:path]

    namespace =
      if given = opts[:namespace] do
        given
      else
        module
        |> Module.split()
        |> Enum.take(1)
        |> Module.concat()
      end

    root_path = Path.join(root, path || Template.module_to_template_root(module, namespace, "View"))
    [root: root_path] ++ Keyword.take(opts, [:pattern, :template_engines])
  end
end
