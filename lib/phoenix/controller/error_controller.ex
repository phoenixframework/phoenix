defmodule Phoenix.Controller.ErrorController do
  use Phoenix.Controller

  plug :action

  @moduledoc """
  Default 404 and 500 error page controller, configured via Mix on each Router

  ## Example Configuration

      config :phoenix, MyApp.Router,
        error_controller: MyApp.ErrorController

      config :phoenix, App.Router,
        error_controller: Phoenix.Controller.ErrorController

  """

  def not_found(conn, _) do
    text conn, 404, "not found"
  end

  def not_found_debug(conn, _) do
    text conn, 404, "No route matches #{conn.method} to #{inspect conn.path_info}"
  end

  def error(conn, _) do
    status = case Phoenix.Controller.Exception.from_conn(conn) do
      %Phoenix.Controller.Exception{status: status} -> status
      :no_exception -> 500
    end

    text conn, status, "Something went wrong"
  end

  @doc """
  Render HTML response with stack trace for use in development
  """
  def error_debug(conn, opts) do
    case Phoenix.Controller.Exception.from_conn(conn) do
      exception = %Phoenix.Controller.Exception{} ->
        Phoenix.Controller.Exception.log(exception)
        render_error_debug(conn, exception)

      :no_exception -> error(conn, opts)
    end
  end
  defp render_error_debug(conn, exception) do
    html conn, exception.status, """
      <html>
        <h2>**(#{inspect exception.type}) #{exception.message}</h2>
        <h4>Stacktrace</h4>
        <body>
          <pre>#{exception.stacktrace_formatted}</pre>
        </body>
      </html>
    """
  end
end

