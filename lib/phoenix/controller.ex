defmodule Phoenix.Controller do
  alias Phoenix.Plugs

  import Plug.Conn
  import Phoenix.Controller.Connection

  @layout_extension_types ["html"]

  @moduledoc """
  Controllers are used to group common functionality in the same
  (pluggable) module.

  For example, the route:

      get "/users/:id", UserController, :show

  will invoke the `show/2` action in the `UserController`:

      defmodule UserController do
        use Phoenix.Controller

        plug :action

        def show(conn, %{"id" => id}) do
          user = Repo.get(User, id)
          render conn, "show.html", user: user
        end
      end

  An action is just a regular function that receives the connection
  and the request parameters as arguments. The connection is a
  `Plug.Conn` struct, as specified by the Plug library.

  ## Connection

  A controller by default provides many convenience functions for
  manipulating the connection, rendering templates, and more.

  Those functions are imported from two modules:

    * `Plug.Conn` - a bunch of low-level functions to work with
      the connection

    * `Phoenix.Controller` - functions provided by Phoenix
      to support rendering, and other Phoenix specific behaviour

  ## Rendering and layouts

  One of the main feature provided by controllers is the ability
  to do content negotiation and render templates based on
  information sent by the client. Read `render/3` for more
  information.

  ## Plug pipeline

  As routers, controllers also have their own plug pipeline. However,
  different from routers, controllers have a single pipeline:

      defmodule UserController do
        use Phoenix.Controller

        plug :authenticate, usernames: ["jose", "eric", "sonny"]
        plug :action

        def show(conn, params) do
          # authenticated users only
        end

        defp authenticate(conn, options) do
          if get_session(conn, :username) in options[:usernames] do
            conn
          else
            conn |> redirect(Router.root_path) |> halt
          end
        end
      end

  The `:action` plug must always be invoked and it represents the action
  to be dispatched to.

  Check `Phoenix.Controller.Pipeline` for more information on `plug/2`
  and how to customize the plug pipeline.
  """
  defmacro __using__(_options) do
    quote do
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.Controller.Connection

      use Phoenix.Controller.Pipeline

      plug Plugs.ContentTypeFetcher
      plug Plugs.ControllerLogger
      plug Phoenix.Controller.Flash
      plug :put_layout, {Phoenix.Controller.__layout__(__MODULE__), :application}
      plug :put_view, Phoenix.Controller.__view__(__MODULE__)
    end
  end

  @doc """
  Stores the view for rendering.
  """
  @spec put_view(Plug.Conn.t, atom) :: Plug.Conn.t
  def put_view(conn, module) do
    put_private(conn, :phoenix_view, module)
  end

  @doc """
  Retrieves the current view.
  """
  @spec view_module(Plug.Conn.t) :: atom
  def view_module(conn) do
    conn.private.phoenix_view
  end

  @doc """
  Stores the layout for rendering.

  The layout must be a tuple, specifying the layout view and the layout
  name, or false. In case a previous layout is set, `put_layout` also
  accepts the layout name to be given as a string or as an atom. If a
  string, it must contain the format. Passing an atom means the layout
  format will be found at rendering time, similar to the template in
  `render/3`.

  ## Examples

      iex> layout(conn)
      false

      iex> conn = put_layout conn, {AppView, "application"}
      iex> layout(conn)
      {AppView, "application"}

      iex> conn = put_layout conn, "print"
      iex> layout(conn)
      {AppView, "print"}

      iex> conn = put_layout :print
      iex> layout(conn)
      {AppView, :print}

  """
  @spec put_layout(Plug.Conn.t, {atom, binary} | binary | false) :: Plug.Conn.t
  def put_layout(conn, layout)

  def put_layout(conn, false) do
    put_private(conn, :phoenix_layout, false)
  end

  def put_layout(conn, {mod, layout}) when is_atom(mod) do
    put_private(conn, :phoenix_layout, {mod, layout})
  end

  def put_layout(conn, layout) when is_binary(layout) or is_atom(layout) do
    update_in conn.private, fn private ->
      case Map.get(private, :phoenix_layout, false) do
        {mod, _} -> Map.put(private, :phoenix_layout, {mod, layout})
        false    -> raise "cannot use put_layout/2 with atom/binary when layout is false, use a tuple instead"
      end
    end
  end

  @doc """
  Retrieves the current layout.
  """
  @spec layout(Plug.Conn.t) :: {atom, binary} | false
  def layout(conn), do: conn.private |> Map.get(:phoenix_layout, false)

  @doc """
  Render the given template or the default template
  specified by the current action with the given assigns.

  See `render/3` for more information.
  """
  def render(conn, template_or_assigns \\ [])

  def render(conn, template) when is_binary(template) or is_atom(template) do
    render(conn, template, [])
  end

  def render(conn, assigns) do
    render(conn, action_name(conn), assigns)
  end

  @doc """
  Renders the given `template` and `assigns` based on the `conn` information.

  Once the template is rendered, the template format is set as the response
  content type (for example, a HTML template will set "text/html" as response
  content type) and the data is sent to the client with default status of 200.

  ## Arguments

    * `conn` - the `Plug.Conn` struct

    * `template` - which may be an atom or a string. If an atom, like `:index`,
      it will render a template with the same format as the one found in
      `conn.params["format"]`. For example, for an HTML request, it will render
      the "index.html" template. If the template is a string, it must contain
      the extension too, like "index.json"

    * `assigns` - a dictionary with the assigns to be used in the view. Those
      assigns are merged and have higher precedence than the connection assigns
      (`conn.assigns`)

  ## Examples

      defmodule MyApp.UserController do
        use Phoenix.Controller

        plug :action

        def show(conn) do
          render conn, "show.html", message: "Hello"
        end
      end

  The example above renders a template "show.html" from the `MyApp.UserView`
  and set the response content type to "text/html".

  In many cases, you may want the template format to be set dynamically based
  on the request. To do so, you can pass the template name as an atom (without
  the extension):

      def show(conn) do
        render conn, :show, message: "Hello"
      end

  In order for the example above to work, we need to do content negotiation with
  the accepts plug. You can do so by adding the following to your pipeline:

      plug :accepts, ~w(html)

  ## Views

  Controllers render by default templates in a view with a similar name to the
  controller. For example, `MyApp.UserController` will render templates inside
  the `MyApp.UserView`. This information can be changed any time by using the
  `put_view/2` function:

      def show(conn) do
        conn
        |> put_view(MyApp.SpecialView)
        |> render(:show, message: "Hello")
      end
.
  `put_view/2` can also be used as a plug:

      defmodule MyApp.UserController do
        use Phoenix.Controller

        plug :put_view, MyApp.SpecialView
        plug :action

        def show(conn) do
          render conn, :show, message: "Hello"
        end
      end

  ## Layouts

  Templates are often rendered inside layouts. By default, Phoenix
  will render layouts for html requests. For example:

      defmodule MyApp.UserController do
        use Phoenix.Controller

        plug :action

        def show(conn) do
          render conn, "show.html", message: "Hello"
        end
      end

  will render the  "show.html" template inside an "application.html"
  template specified in `MyApp.LayoutView`. `put_layout/2` can be used
  to change the layout, similar to how `put_view/2` can be used to change
  the view.

  `layout_formats/2` and `put_layout_formats/2` can be used to configure
  which formats support/require layout rendering (defaults to "html" only).
  """
  def render(conn, template, assigns) when is_atom(template) do
    format =
      conn.params["format"] ||
      raise "cannot render template #{inspect template} because conn.params[\"format\"] is not set. " <>
            "Please set `plug :accepts, %w(html json ...)` in your pipeline."
    render(conn, template_name(template, format), format, assigns)
  end

  def render(conn, template, assigns) when is_binary(template) do
    case Path.extname(template) do
      "." <> format ->
        render(conn, template, format, assigns)
      "" ->
        raise "cannot render template #{inspect template} without format. Use an atom if the " <>
              "template format is meant to be set dynamically based on the request format"
    end
  end

  def render(conn, template, format, assigns) do
    content_type = Plug.MIME.type(format)
    conn = prepare_assigns(conn, assigns, format)
    data = Phoenix.View.render_to_iodata(view_module(conn), template,
                                         Map.put(conn.assigns, :conn, conn))

    conn
    |> put_resp_content_type(content_type)
    |> send_resp(conn.status || 200, data)
  end

  defp prepare_assigns(conn, assigns, format) do
    layout =
      case layout(conn, assigns, format) do
        {mod, layout} -> {mod, template_name(layout, format)}
        false -> false
      end

    update_in conn.assigns,
              & &1 |> Dict.merge(assigns) |> Map.put(:within, layout)
  end

  defp layout(conn, assigns, format) do
    if format in @layout_extension_types do
      case Dict.fetch(assigns, :within) do
        {:ok, layout} -> layout
        :error -> layout(conn)
      end
    else
      false
    end
  end

  defp template_name(name, format) when is_atom(name), do:
    Atom.to_string(name) <> "." <> format
  defp template_name(name, _format) when is_binary(name), do:
    name

  @doc false
  def __view__(controller_module) do
    controller_module
    |> Phoenix.Naming.unsuffix("Controller")
    |> Kernel.<>("View")
    |> Module.concat(nil)
  end

  @doc false
  def __layout__(controller_module) do
    controller_module
    |> Module.split
    |> Enum.at(0)
    |> Module.concat("LayoutView")
  end
end
