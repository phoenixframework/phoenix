defmodule Phoenix.Controller.PageController do
  use Phoenix.Controller


  def not_found(conn, _) do
    text conn, 404, "not found"
  end

  def not_found_debug(conn, _) do
    text conn, 404, "No route matches #{conn.method} to #{inspect conn.path_info}"
  end

  def error(conn, _) do
    status = case error(conn) do
      {_kind, err} -> Plug.Exception.status(err)
      _            -> 500
    end

    text conn, status, "Something went wrong"
  end

  @doc """
  Render HTML response with stack trace for use in development
  """
  def error_debug(conn, opts) do
    case error(conn) do
      {_kind, err} ->
        status         = Plug.Exception.status(err)
        stacktrace     = System.stacktrace
        exception      = Exception.normalize(:error, err)
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
      _ -> error(conn, opts)
    end
  end
end

