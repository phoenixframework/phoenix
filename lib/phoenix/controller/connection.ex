defmodule Phoenix.Controller.Connection do
  import Plug.Conn
  alias Plug.Conn
  alias Phoenix.Status
  alias Phoenix.Controller.Errors

  @moduledoc """
  Handles Interacting with Plug.Conn and integration with the Controller layer

  Used for sending responses, halting connections, and looking up private Conn
  assigns
  """

  @unsent [:unset, :set]

  @doc """
  Returns the Atom action name matched from Router
  """
  def action_name(conn), do: conn.private[:phoenix_action]

  @doc """
  Returns the Atom Controller Module matched from Router
  """
  def controller_module(conn), do: conn.private[:phoenix_controller]

  @doc """
  Retrieve or Assign layout to phoenix private assigns
  """
  def layout(conn, layout), do: assign_private(conn, :phoenix_layout, layout)
  def layout(conn), do: Dict.get(conn.private, :phoenix_layout, "application")

  @doc """
  Updates the Conn status
  """
  def status(conn, status), do: put_in(conn.status, status)

  @doc """
  Halts the Plug chain by throwing `{:halt, conn}`.
  If no response has been sent, an empty Bad Request is sent before throwing
  error.

  ## Examples

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
    text(conn, 400, "Bad Request") |> halt!
  end
  def halt!(conn) do
    throw {:halt, conn}
  end

  @doc """
  Returns the String Mime content-type of response
  """
  def response_content_type(conn) do
    conn.private[:phoenix_content_type] || raise(
      %Errors.UnfetchedContentType{message: "You must first call Plugs.ContentTypeFetcher.fetch/1"}
    )
  end

  @doc """
  Sends JSON response from provided json String

  ## Examples

      json conn, "{\"id\": 123}"
      json conn, 200, "{\"id\": 123}"

  """
  def json(conn, json), do: json(conn, :ok, json)
  def json(conn, status, json) do
    send_response(conn, status, "application/json", json)
  end

  @doc """
  Sends HTML response from provided html String

  ## Examples

      html conn, "<h1>Hello!</h1>"
      html conn, 200, "<h1>Hello!</h1>"

  """
  def html(conn, html), do: html(conn, :ok, html)
  def html(conn, status, html) do
    send_response(conn, status, "text/html", html)
  end

  @doc """
  Sends text response from provided String

  ## Examples

      text conn, "hello"
      text conn, 200, "hello"

  """
  def text(conn, text), do: text(conn, :ok, text)
  def text(conn, status, text) do
    send_response(conn, status, "text/plain", text)
  end

  @doc """
  Sends response to the client

    * conn - the Plug Connection
    * status - The Integer or Atom http status, ie 200, 400, :ok, :bad_request
    * content_type - The String Mime content type of the response, ie, "text/html"

  """
  def send_response(conn, status, content_type, data) do
    conn
    |> put_resp_content_type(content_type)
    |> send_resp(Status.code(status), data)
  end

  @doc """
  Sends redirect response to provided url String

  ## Examples

      redirect conn, "http://elixir-lang.org"
      redirect conn, 404, "http://elixir-lang.org"

  """
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
end
