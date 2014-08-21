defmodule Phoenix.Controller.Action do
  import Phoenix.Controller.Connection
  import Plug.Conn
  alias Phoenix.Config
  alias Phoenix.Router.Path

  @doc """
  Carries out Controller action after successful Router match, invoking the
  "2nd layer" Plug stack.

  Connection query string parameters are fetched automatically before
  controller actions are called, as well as merging any named parameters from
  the route definition.
  """
  def perform(conn, controller, action, named_params) do
    conn = assign_private(conn, :phoenix_named_params, named_params)
    |> assign_private(:phoenix_action, action)
    |> assign_private(:phoenix_controller, controller)

    apply(controller, :call, [conn, []])
  end

  @doc """
  Sends 404 not found response to client
  """
  def handle_error(conn, :throw, {:not_found, conn}) do
    router = router_module(conn)

    if controller = Config.router(router, [:error_controller]) do
      controller.handle_error(conn, :throw, {:not_found, conn})
    else
      text conn, :not_found, "No route matches #{conn.method} to #{Path.join(conn.path_info)}"
    end
  end
  def handle_error(conn, kind, error) do
    router    = router_module(conn)

    cond do
      Config.router(router, [:consider_all_requests_local]) ->
        error_with_trace(conn, kind, error)

      controller = Config.router(router, [:error_controller]) ->
        controller.handle_error(conn, kind, error)

      true ->
        status = Plug.Exception.status(error)
        html conn, status, """
          <html>
            <body>
              <pre>Something went wrong</pre>
            </body>
          </html>
        """
    end
  end


  @doc """
  Render HTML response with stack trace for use in development
  """
  def error_with_trace(conn, _kind, error) do
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
end
