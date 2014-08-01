defmodule Phoenix.Controller do
  import Phoenix.Controller.Connection
  alias Plug.MIME
  alias Phoenix.Plugs
  alias Phoenix.View

  @default_content_type "text/html"
  @plug_default_mime_type "application/octet-stream"

  @moduledoc """
  Phoenix Controllers are responsible for handling the dispatch of Router requests

  Like Routers, Controllers are Plugs, but contain a required :action plug that
  is implicitly added to the end plug chain. The :action proxies to the function
  defined in the Router. The :action plug can be explicitly added to change
  its execution order.

  ## Examples

      defmodule MyApp.Controllers.Admin.Users do
        use Phoenix.Controller

        plug :authenticate, usernames: ["jose", "eric", "sonny"]

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
    quote do
      import Plug.Conn
      import Phoenix.Controller.Connection
      import unquote(__MODULE__)
      alias Phoenix.Controller.Flash
      @options unquote(options)

      @subview_module view_module(__MODULE__)
      @layout_module layout_module(__MODULE__)

      def init(options), do: options
      @before_compile unquote(__MODULE__)
      use Plug.Builder
      unless @options[:bare] do
        plug Plugs.ParamsFetcher
        plug Plugs.ContentTypeFetcher
        plug Phoenix.Controller.Flash
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      unless Plugs.plugged?(@plugs, :action) do
        plug :action
      end

      def action(conn, _options) do
        apply(__MODULE__, conn.private[:phoenix_action], [conn, conn.params])
      end

      def render(conn, template, assigns \\ []) do
        render_view conn, @subview_module, @layout_module, template, assigns
      end
      defoverridable action: 2
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
    content_type = response_content_type(conn)
    exts         = MIME.extensions(content_type)
    status       = conn.status || 200
    conn         = prepare_for_render(conn, assigns, layout_mod, exts)
    content = View.render(view_mod, template_name(template, exts), conn.assigns)

    send_response(conn, status, content_type, content)
  end
  defp template_name(template, extensions)
  defp template_name(template, []), do: template
  defp template_name(template, [ext | _]), do: "#{template}.#{ext}"
  defp prepare_for_render(conn, assigns, layout_mod, exts) do
    assigns = Dict.put_new(assigns, :conn, conn)
    layout = layout(conn)
    if is_binary layout do
      assigns = Dict.put_new(assigns, :within, {layout_mod, template_name(layout, exts)})
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
