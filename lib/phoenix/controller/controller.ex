defmodule Phoenix.Controller do
  import Plug.Connection

  defmacro __using__(_options) do
    quote do
      import Plug.Connection
      import unquote(__MODULE__)
    end
  end

  def json(conn, json), do: json(conn, 200, json)
  def json(conn, status, json) do
    send_response(conn, status, "application/json", json)
  end

  def html(conn, html), do: html(conn, 200, html)
  def html(conn, status, html) do
    send_response(conn, status, "text/html", html)
  end

  def text(conn, text), do: text(conn, 200, text)
  def text(conn, status, text) do
    send_response(conn, status, "text/plain", text)
  end

  def send_response(conn, status, content_type, data) do
    {:ok,
      conn
      |> put_resp_content_type(content_type)
      |> send_resp(status, data)
    }
  end

  def not_found(conn, method, path) do
    text conn, 404, "No route matches #{method} to #{inspect path}"
  end

  def error(conn, reason) do
    html conn, 500, """
    <h1>Internal Server Error</h1>
    <blockquote>#{inspect reason}</blockquote>
    """
  end
end

