defmodule Phoenix.Controller do
  import Phoenix.Controller.Connection
  alias Plug.MIME
  alias Phoenix.Plugs
  alias Phoenix.View

  @default_content_type "text/html"
  @plug_default_mime_type "application/octet-stream"
  @layout_extension_types ["html"]

  @moduledoc """
  Phoenix Controllers are responsible for handling the dispatch of Router requests

  Like Routers, Controllers are Plugs, but contain a required :action plug that
  is implicitly added to the end plug chain. The :action proxies to the function
  defined in the Router. The :action plug can be explicitly added to change
  its execution order.

  ## Examples

      defmodule MyApp.Controllers.Admin.Users do
        use Phoenix.Controller

        before_action :authenticate, usernames: ["jose", "eric", "sonny"]

        def authenticate(conn, options) do
          if get_session(conn, username) in options[:usernames] do
            conn
          else
            conn |> redirect(Router.root_path) |> halt!
          end
        end

        def show(conn, params) do
          # authenticated users only
        end
      end

  ## Controller Actions

  Controllers inject an `action/2` function into all using modules. This
  invokes the corresponding function mapped in the router and stored in the
  private `phoenix_action` assign. For custom action handling, `action/2` can be
  overriden, ie:

      def action(conn = %Conn{private: %{phoenix_action: action}, params) do
        find_module_for_action(action).call(conn, params)
      end

  """
  defmacro __using__(options) do
    quote bind_quoted: [options: options] do
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.Controller.Connection

      use Phoenix.Controller.Stack

      @subview_module view_module(__MODULE__)
      @layout_module layout_module(__MODULE__)

      def render(conn, template, assigns \\ []) do
        render_view conn, @subview_module, @layout_module, template, assigns
      end

      unless options[:bare] do
        before_action Plugs.ContentTypeFetcher
        before_action Phoenix.Controller.Flash
        before_action Plugs.ControllerLogger
      end
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
