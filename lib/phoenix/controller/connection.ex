defmodule Phoenix.Controller.Connection do
  import Plug.Conn
  alias Phoenix.Controller.Errors

  # TODO: Remove this module
  @moduledoc false

  @doc """
  Returns the String Mime content-type of response

  Raises Errors.UnfetchedContentType if content type is not yet fetched
  """
  def response_content_type!(conn) do
    case response_content_type(conn) do
      {:ok, resp}   -> resp
      {:error, :unfetched} -> raise Errors.UnfetchedContentType, message: "You must first call Plugs.ContentTypeFetcher.fetch/1"
    end
  end

  @doc """
  Returns the String Mime content-type of response

  ## Examples

      iex> response_content_type(conn)
      {:ok, "text/html"}
      iex> response_content_type(conn)
      {:error, :unfetched}

  """
  def response_content_type(conn) do
    conn
    |> get_resp_header("content-type")
    |> Enum.at(0)
    |> case do
      nil -> {:error, :unfetched }
      headers -> {:ok, headers |> String.split(";") |> Enum.at(0)}
    end
  end

  @doc """
  Upgrades the connection
  """
  def upgrade(conn, [{transport, handler}]) do
    put_private(conn, :upgrade, {transport, handler}) |> halt
  end

  @doc """
  Sends JSON response from provided json String

  ## Examples

      json conn, "{\"id\": 123}"
      json conn, 200, "{\"id\": 123}"

  """
  def json(conn, status, json) do
    IO.write :stderr, "json/3 is deprecated, please use json/2 + put_status/2 instead\n#{Exception.format_stacktrace}"
    send_response(conn, status, "application/json", json)
  end

  @doc """
  Sends HTML response from provided html String

  ## Examples

      html conn, "<h1>Hello!</h1>"
      html conn, 200, "<h1>Hello!</h1>"

  """
  def html(conn, status, html) do
    IO.write :stderr, "html/3 is deprecated, please use html/2 + put_status/2 instead\n#{Exception.format_stacktrace}"
    send_response(conn, status, "text/html", html)
  end

  @doc """
  Sends text response from provided String

  ## Examples

      text conn, "hello"
      text conn, 200, "hello"

  """
  def text(conn, status, text) do
    IO.write :stderr, "text/3 is deprecated, please use text/2 + put_status/2 instead\n#{Exception.format_stacktrace}"
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
    |> send_resp(status, data)
  end
end
