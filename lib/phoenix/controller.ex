defmodule Phoenix.Controller do
  alias Plug.Conn
  import Plug.Conn
  alias Phoenix.Status
  alias Phoenix.Mime

  @default_content_type "text/html"
  @unsent [:unset, :set]

  @moduledoc """
  Phoenix Controllers are responsible for handling the dispatch of Router requests

  Like Routers, Controllers are Plugs, but contain a required :action plug that
  is implicitly added to the end plug chain. The :action proxies to the function
  defined in the Router. The :action plug can be explicitly added to change
  its execution order.

  Examples

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
  """
  defmacro __using__(_options) do
    quote do
      import Plug.Conn
      import unquote(__MODULE__)

      def init(options), do: options
      @before_compile unquote(__MODULE__)
      use Plug.Builder
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      unless Enum.find(@plugs, fn {plug, _opts} -> plug == :action end) do
        plug :action
      end
      def action(conn, _options) do
        apply(__MODULE__, conn.private[:phoenix_action], [conn, conn.params])
      end
    end
  end

  @doc """
  Carries out Controller action after successful Router match, invoking the
  "2nd layer" Plug stack.

  Connection query string parameters are fetched automatically before
  controller actions are called, as well as merging any named parameters from
  the route definition.
  """
  def perform_action(conn, controller, action, named_params) do
    conn = Conn.fetch_params(conn) |> Conn.assign_private(:phoenix_action, action)
    conn = %{conn | params: Dict.merge(conn.params, named_params) }
    apply(controller, :call, [conn, []])
  end

  @doc """
  Returns the Atom action name matched from Router
  """
  def action_name(conn), do: conn.private[:phoenix_action]

  @doc """
  Halts the Plug chain by throwing `{:halt, conn}`.
  If no response has been sent, an empty Bad Request is sent before throwing
  error.

  Examples
    plug :authenticate

    def authenticate(conn, _opts) do
      if authenticate?(conn) do
        conn
      else
        conn
        |> redirect(Router.root_path)
        |> halt!
       end
    end
  """
  def halt!(conn = %Conn{state: state}) when state in @unsent do
    send_resp(conn, 400, "") |> halt!
  end
  def halt!(conn) do
    throw {:halt, conn}
  end

  def json(conn, json), do: json(conn, :ok, json)
  def json(conn, status, json) do
    send_response(conn, status, "application/json", json)
  end

  def html(conn, html), do: html(conn, :ok, html)
  def html(conn, status, html) do
    send_response(conn, status, "text/html", html)
  end

  def text(conn, text), do: text(conn, :ok, text)
  def text(conn, status, text) do
    send_response(conn, status, "text/plain", text)
  end

  def send_response(conn, status, content_type, data) do
    conn
    |> put_resp_content_type(content_type)
    |> send_resp(Status.code(status), data)
  end

  def redirect(conn, url), do: redirect(conn, :found, url)
  def redirect(conn, status, url) do
    conn
    |> put_resp_header("Location", url)
    |> html status, """
       <html>
         <head>
            <title>Moved</title>
         </head>
         <body>
           <h1>Moved</h1>
           <p>This page has moved to <a href="#{url}">#{url}</a></p>
         </body>
       </html>
    """
  end

  def not_found(conn, method, path) do
    text conn, :not_found, "No route matches #{method} to #{inspect path}"
  end

  def error(conn, error) do
    status = Plug.Exception.status(error)

    html conn, status, """
      <html>
        <body>
          <pre>Something went wrong</pre>
        </body>
      </html>
    """
  end

  def error_with_trace(conn, error) do
    stacktrace     = System.stacktrace
    exception      = Exception.normalize(:error, error)
    status         = Plug.Exception.status(error)
    exception_type = exception.__struct__

    html conn, status, """
      <html>
        <h2>(#{inspect exception_type}) #{Exception.message(exception)}</h2>
        <h4>Stacktrace</h4>
        <body>
          <pre>#{Exception.format_stacktrace stacktrace}</pre>
        </body>
      </html>
    """
  end

  @doc """
  Renders View template and sends response based on Controller module name and
  request content-type

  conn - The Plug.Conn struct
  template - The String template name, ie "show", "index"
  assigns - The optional dict assigns to pass to template when rendering

  Examples

  defmodule MyApp.Controllers.Users do
    def show(conn) do
      render conn, "show", name: "José"
    end
  end

  Expands at compile time to:

    MyApp.Views.Users.render("show.html",
      name: "José",
      within: {MyApp.Views.Layouts, "application.html"}
    )

  """
  defmacro render(conn, template, assigns \\ []) do
    subview_module = view_module(__CALLER__.module, controller_name(__CALLER__.module))
    layout_module  = view_module(__CALLER__.module, "Layouts")

    quote do
      render_view unquote(conn),
                  unquote(subview_module),
                  unquote(layout_module),
                  unquote(template),
                  unquote(assigns)
    end
  end

  def render_view(conn, view_mod, layout_mod, template, assigns \\ []) do
    assigns      = Dict.merge(conn.assigns, assigns)
    content_type = response_content_type(conn)
    extension    = Mime.ext_from_type(content_type) || ""
    layout       = Dict.get(assigns, :layout, "application")
    assigns      = Dict.put_new(assigns, :within, {layout_mod, layout <> extension})
    status       = Dict.get(assigns, :status, 200)

    {:safe, rendered_content} = view_mod.render(template <> extension, assigns)

    send_response(conn, status, content_type, rendered_content)
  end

  @doc """
  Returns the List of String Accept headers, in order of priority
  """
  def accept_formats(conn) do
    conn
    |> get_req_header("accept")
    |> parse_accept_headers
  end
  defp parse_accept_headers([]), do: []
  defp parse_accept_headers([accepts | _rest]) do
    accepts
    |> String.split(",")
    |> Enum.map fn format ->
      String.split(format, ";") |> Enum.at(0)
    end
  end

  @doc """
  Returns the String response content-type

  Lookup priority
  1. format param of mime extension, ie "html", "json", "xml"
  2. Accept header, ie "text/html,application/xml;q=0.9,*/*;q=0.8"
  3. "text/html" default fallback
  """
  def response_content_type(conn) do
    ".#{conn.params["format"]}"
    |> Mime.type_from_ext
    |> Kernel.||(primary_accept_format(accept_formats(conn)))
    |> Kernel.||(@default_content_type)
  end
  defp primary_accept_format(["*/*" | _rest]), do: @default_content_type
  defp primary_accept_format([type | _rest]), do: Mime.valid_type?(type) && type
  defp primary_accept_format(_), do: nil

  @doc """
  Returns the String content-type fron Conn headers.  Defaults "text/html"
  """
  def get_content_type(conn) do
    Enum.at(get_req_header(conn, "content-type"), 0) || @default_content_type
  end

  @doc """
  Finds View module based on controller_module

  Examples

  iex> Controller.view_module(MyApp.Controllers.Users)
  MyApp.Views

  iex> Controller.view_module(MyApp.Controllers.Users, Layouts)
  MyApp.Views.Layouts

  """
  def view_module(controller_module, submodule \\ nil) do
    controller_module
    |> Module.split
    |> Enum.at(0)
    |> Module.concat("Views")
    |> Module.concat(submodule)
  end

  @doc """
  Returns the atom controller module name without application and controller
  module prefix

  Examples

  iex> controller_name(MyApp.Controllers.Admin.Users)
  Admin.Users
  """
  def controller_name(controller_module) do
    controller_module
    |> Module.split
    |> Enum.reverse
    |> Enum.take_while(&(&1 !== "Controllers"))
    |> Enum.reverse
    |> Module.concat
  end

end
