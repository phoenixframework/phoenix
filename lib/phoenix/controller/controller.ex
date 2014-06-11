defmodule Phoenix.Controller do
  import Plug.Conn
  alias Phoenix.Status

  defmacro __using__(_options) do
    quote do
      import Plug.Conn
      import unquote(__MODULE__)
    end
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
    stacktrace = System.stacktrace
    exception  = Exception.normalize(:error, error)
    status     = Plug.Exception.status(error)

    html conn, status, """
      <html>
        <h2>(#{inspect exception.__struct__}) #{exception.message}</h2>
        <h4>Stacktrace</h4>
        <body>
          <pre>#{Exception.format_stacktrace stacktrace}</pre>
        </body>
      </html>
    """
  end
end
