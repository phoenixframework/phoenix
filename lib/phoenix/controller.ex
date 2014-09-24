defmodule Phoenix.Controller do
  import Phoenix.Controller.Connection
  alias Plug.MIME
  alias Phoenix.Plugs
  alias Phoenix.View

  @default_content_type "text/html"
  @plug_default_mime_type "application/octet-stream"
  @layout_extension_types ["html"]

  @moduledoc """
  Controllers are conveniences for handling router requests.

  For example, the route:

      get "/users/:id", UserController, :show

  will invoke the `show/2` action in the `UserController`:

      defmodule UserController do
        use Phoenix.Controller

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

    * `Phoenix.Controller.Connection` - functions provided by Phoenix
      to support rendering, and other Phoenix specific behaviour

  ## Rendering and layouts

  TODO: documentation.

  ## Plug stacks

  As routers, controllers also have their own plug stack, allowing developers
  to execute a particular plug before or after an action:

      defmodule UserController do
        use Phoenix.Controller

        before_action :authenticate, usernames: ["jose", "eric", "sonny"]

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

  Check `Phoenix.Controller.Stack` for more information on `before_action/2`
  and how to customize the plug stack.
  """
  defmacro __using__(_options) do
    quote do
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.Controller.Connection

      use Phoenix.Controller.Stack

      @subview_module view_module(__MODULE__)
      @layout_module layout_module(__MODULE__)

      def render(conn, template, assigns \\ []) do
        render_view conn, @subview_module, @layout_module, template, assigns
      end

      before_action Plugs.ContentTypeFetcher
      before_action Phoenix.Controller.Flash
      before_action Plugs.ControllerLogger
    end
  end

  @doc """
  Renders View with template based on Mime Accept headers

    * conn - The Plug.Conn struct
    * view_mod - The View module to call `render/2` on
    * layout_mod - The Layout module to render
    * template - The String template name, ie "show", "index".
                 An empty list `[]` from `plug :render` automatically assigns
                 the template as the action_name of the connection

    * assigns - The optional dict assigns to pass to template when rendering

  ## Examples

      # Explicit rendering

      defmodule MyApp.UserController do
        use Phoenix.Controller

        def show(conn) do
          render conn, "show", name: "José"
        end
      end

      # Automatic rendering with `plug :render`

      defmodule MyApp.UserController do
        use Phoenix.Controller

        plug :action
        plug :render

        def show(conn) do
          assign(conn, :name, "José")
        end
      end


  """
  def render_view(conn, view_mod, layout_mod, template, assigns \\ [])
  def render_view(conn, view_mod, layout_mod, [], assigns) do
    render_view conn, view_mod, layout_mod, action_name(conn), assigns
  end
  def render_view(conn, view_mod, layout_mod, template, assigns) do
    template     = template || action_name(conn)
    content_type = response_content_type!(conn)
    ext          = MIME.extensions(content_type) |> Enum.at(0)
    status       = conn.status || 200
    conn         = prepare_for_render(conn, assigns, layout_mod, ext)
    content = View.render(view_mod, template_name(template, ext), conn.assigns)

    send_response(conn, status, content_type, content)
  end
  defp template_name(template, nil), do: template
  defp template_name(template, ext), do: "#{template}.#{ext}"
  defp prepare_for_render(conn, assigns, layout_mod, ext) do
    assigns = Dict.put_new(assigns, :conn, conn)
    layout = layout(conn)
    if is_binary(layout) && ext in @layout_extension_types do
      assigns = Dict.put_new(assigns, :within, {layout_mod, template_name(layout, ext)})
    end

    update_in(conn.assigns, &Dict.merge(&1, assigns))
  end

  @doc """
  Finds View module based on controller_module

  ## Examples

      iex> Controller.view_module(MyApp.UserController)
      MyApp.UserView

      iex> Controller.view_module(MyApp.Admin.UserController)
      MyApp.Admin.UserView

  """
  def view_module(controller_module) do
    controller_module
    |> to_string
    |> String.replace(~r/^(.*)(Controller)$/, "\\1View")
    |> Module.concat(nil)
  end

  @doc """
  Finds Layout View module based on Controller Module

  ## Examples

      iex> Controller.layout_module(MyApp.UserController)
      MyApp.LayoutView
  """
  def layout_module(controller_module) do
    controller_module
    |> Module.split
    |> Enum.at(0)
    |> Module.concat("LayoutView")
  end
end
