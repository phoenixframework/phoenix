defmodule Phoenix.ConnTest do
  @moduledoc """
  Conveniences for testing Phoenix endpoints and
  connection related helpers.

  You likely want to use this module or make it part of
  your `ExUnit.CaseTemplate`. Once used, this module
  automatically imports all functions defined here as
  well as the functions in `Plug.Conn`.

  ## Endpoint testing

  `Phoenix.ConnTest` typically works against endpoints. That's
  the preferred way to test anything that your router dispatches
  to.

      conn = get conn(), "/"
      assert conn.resp_body =~ "Welcome!"

      conn = post conn(), "/login", [username: "john", password: "doe"]
      assert conn.resp_body =~ "Logged in!"

  As in your application, the connection is also the main abstraction
  in testing. `conn()` returns a new connection and functions in this
  module can be used to manipulate the connection before dispatching
  to the endpoint.

  For example, one could set the accepts header for json requests as
  follows:

      conn()
      |> put_req_header("accept", "application/json")
      |> get("/")

  The endpoint being tested is accessed via the `@endpoint` module
  attribute.

  ## Controller testing

  The functions in this module can also be used for controller
  testing. While endpoint testing is preferred over controller
  testing as a controller often depends on the pipelines invoked
  in the router and before, unit testing controllers may be helpful
  in some situations.

  For such cases, just pass an atom representing the action
  to dispatch:

      conn = get conn(), :index
      assert conn.resp_body =~ "Welcome!"

  ## Views testing

  Under other circumstances, you may be testing a view or
  another layer that requires a connection for processing.
  For such cases, a connection can be created using the
  `conn/3` helper:

      MyApp.UserView.render "hello.html",
                             conn: conn(:get, "/")

  ## Recycling

  Browsers implement a storage by using cookies. When a cookie
  is set in the response, the browser stores it and sends it in
  the next request.

  To emulate this behaviour, this module provides the idea of
  recycling. The `recycle/1` function receives a connection and
  returns a new connection, similar to the one returned by
  `conn/0` with all the response cookies from the previous
  connection defined as request headers. This is useful when
  testing multiple routes that require cookies or session to
  work.

  Keep in mind Phoenix will automatically recycle the connection
  between dispatches. This usually works out well most times but
  it may discard information if you are modifying the connection
  before the next dispatch:

      # No recycling as the connection is fresh
      conn = get conn(), "/"

      # The connection is recycled, creating a new one behind the scenes
      conn = post conn, "/login"

      # We can also recycle manually in case we want custom headers
      conn = recycle(conn)
      conn = put_req_header("x-special", "nice")

      # No recycling as we did it explicitly
      conn = delete conn, "/logout"

  Recycling also recycles the "accept" header.
  """

  @doc false
  defmacro __using__(_) do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
    end
  end

  alias Plug.Conn

  @doc """
  Creates a connection to be used in upcoming requests.
  """
  @spec conn() :: Conn.t
  def conn() do
    conn(:get, "/", nil)
  end

  @doc """
  Creates a connection to be used in upcoming requests
  with a preset method, path and body.

  This is useful when a specific connection is required
  for testing a plug or a particular function.
  """
  @spec conn() :: Conn.t
  def conn(method, path, params_or_body \\ nil) do
    Plug.Adapters.Test.Conn.conn(%Conn{}, method, path, params_or_body)
    |> Conn.put_private(:plug_skip_csrf_protection, true)
    |> Conn.put_private(:phoenix_recycled, true)
  end

  @http_methods [:get, :post, :put, :patch, :delete, :options, :connect, :trace, :head]

  for method <- @http_methods do
    @doc """
    Dispatches to the current endpoint.

    See `dispatch/5` for more information.
    """
    defmacro unquote(method)(conn, path_or_action, params_or_body \\ nil) do
      method = unquote(method)
      quote do
        Phoenix.ConnTest.dispatch(unquote(conn), @endpoint, unquote(method),
                                  unquote(path_or_action), unquote(params_or_body))
      end
    end
  end

  @doc """
  Dispatches the connection to the given endpoint.

  When invoked via `get/3`, `post/3` and friends, the endpoint
  is automatically retrieved from the `@endpoint` module
  attribute, otherwise it must be given as an argument.

  The connection will be configured with the given `method`,
  `path_or_action` and `params_or_body`.

  If `path_or_action` is a string, it is considered to be the
  request path and stored as so in the connection. If an atom,
  it is assumed to be an action and the connection is dispatched
  to the given action.

  ## Parameters and body

  This function, as well as `get/3`, `post/3` and friends, accepts the
  request body or parameters as last argument:

        get conn(), "/", some: "param"
        get conn(), "/", "some=param&url=encoded"

  The allowed values are:

    * `nil` - meaning there is no body

    * a binary - containing a request body. For such cases, `:headers`
      must be given as option with a content-type

    * a map or list - containing the parameters which will automatically
      set the content-type to multipart. The map or list may contain
      other lists or maps and all entries will be normalized to string
      keys
  """
  def dispatch(conn, endpoint, method, path_or_action, params_or_body \\ nil) do
    if is_nil(endpoint) do
      raise "no @endpoint set in test case"
    end

    if is_binary(params_or_body) and is_nil(List.keyfind(conn.req_headers, "content-type", 0)) do
      raise ArgumentError, "a content-type header is required when setting " <>
                           "a binary body in a test connection"
    end

    conn
    |> ensure_recycled()
    |> dispatch_endpoint(endpoint, method, path_or_action, params_or_body)
    |> Conn.put_private(:phoenix_recycled, false)
    |> from_set_to_sent()
  end

  defp dispatch_endpoint(conn, endpoint, method, path, params_or_body) when is_binary(path) do
    conn
    |> Plug.Adapters.Test.Conn.conn(method, path, params_or_body)
    |> endpoint.call(endpoint.init([]))
  end

  defp dispatch_endpoint(conn, endpoint, method, action, params_or_body) when is_atom(action) do
    conn
    |> Plug.Adapters.Test.Conn.conn(method, "/", params_or_body)
    |> endpoint.call(endpoint.init(action))
  end

  defp from_set_to_sent(%Conn{state: :set} = conn), do: Conn.send_resp(conn)
  defp from_set_to_sent(conn), do: conn

  @doc """
  Puts a request cookie.
  """
  @spec put_req_cookie(Conn.t, binary, binary) :: Conn.t
  defdelegate put_req_cookie(conn, key, value), to: Plug.Test

  @doc """
  Deletes a request cookie.
  """
  @spec delete_req_cookie(Conn.t, binary) :: Conn.t
  defdelegate delete_req_cookie(conn, key), to: Plug.Test

  @doc """
  Fetches the flash storage.
  """
  @spec fetch_flash(Conn.t) :: Conn.t
  defdelegate fetch_flash(conn), to: Phoenix.Controller

  @doc """
  Gets the whole flash storage.
  """
  @spec get_flash(Conn.t) :: Conn.t
  defdelegate get_flash(conn), to: Phoenix.Controller

  @doc """
  Gets the given key from the flash storage.
  """
  @spec get_flash(Conn.t, term) :: Conn.t
  defdelegate get_flash(conn, key), to: Phoenix.Controller

  @doc """
  Puts the given value under key in the flash storage.
  """
  @spec put_flash(Conn.t, term, term) :: Conn.t
  defdelegate put_flash(conn, key, value), to: Phoenix.Controller

  @doc """
  Clears up the flash storage.
  """
  @spec clear_flash(Conn.t) :: Conn.t
  defdelegate clear_flash(conn), to: Phoenix.Controller

  @doc """
  Returns the content type as long as it matches the given format.

  ## Examples

      # Assert we have an html repsonse with utf-8 charset
      assert response_content_type(conn, :html) =~ "charset=utf-8"

  """
  @spec response_content_type(Conn.t, atom) :: String.t | no_return
  def response_content_type(conn, format) when is_atom(format) do
    case Conn.get_resp_header(conn, "content-type") do
      [] ->
        raise "no content-type was set, expected a #{format} response"
      [h] ->
        if response_content_type?(h, format) do
          h
        else
          raise "expected content-type for #{format}, got: #{inspect h}"
        end
      [_|_] ->
        raise "more than one content-type was set, expected a #{format} response"
    end
  end

  defp response_content_type?(header, format) do
    case parse_content_type(header) do
      {part, subpart} ->
        format = Atom.to_string(format)
        format in Plug.MIME.extensions(part <> "/" <> subpart) or
          format == subpart or String.ends_with?(subpart, "+" <> format)
      _  ->
        false
    end
  end

  defp parse_content_type(header) do
    case Plug.Conn.Utils.content_type(header) do
      {:ok, part, subpart, _params} ->
        {part, subpart}
      _ ->
        false
    end
  end

  @doc """
  Asserts the given status code and returns the response body
  if one was set or sent.

  ## Examples

      conn = get conn(), "/"
      assert response(conn, 200) =~ "hello world"

  """
  @spec response(Conn.t, status :: integer | atom) :: binary | no_return
  def response(%Conn{state: :unset}, _status) do
    raise """
    expected connection to have a response but no response was set/sent.
    Please verify that you assign to "conn" after a request:

        conn = get conn, "/"
        assert html_response(conn) =~ "Hello"
    """
  end

  def response(%Conn{status: status, resp_body: body}, given) do
    given = Plug.Conn.Status.code(given)

    if given == status do
      body
    else
      raise "expected response with status #{given}, got: #{status}"
    end
  end

  @doc """
  Asserts the given status code, that we have an html response and
  returns the response body if one was set or sent.

  ## Examples

      assert html_response(conn, 200) =~ "<html>"
  """
  @spec html_response(Conn.t, status :: integer | atom) :: String.t | no_return
  def html_response(conn, status) do
    body = response(conn, status)
    _    = response_content_type(conn, :html)
    body
  end

  @doc """
  Asserts the given status code, that we have an text response and
  returns the response body if one was set or sent.

  ## Examples

      assert text_response(conn, 200) =~ "hello"
  """
  @spec text_response(Conn.t, status :: integer | atom) :: String.t | no_return
  def text_response(conn, status) do
    body = response(conn, status)
    _    = response_content_type(conn, :text)
    body
  end

  @doc """
  Asserts the given status code, that we have an json response and
  returns the decoded JSON response if one was set or sent.

  ## Examples

      body = json_response(conn, 200)
      assert "can't be blank" in body["errors"]

  """
  @spec json_response(Conn.t, status :: integer | atom) :: map | no_return
  def json_response(conn, status) do
    body = response(conn, status)
    _    = response_content_type(conn, :json)
    case Poison.decode(body) do
      {:ok, body} ->
        body
      {:error, {:invalid, token}} ->
        raise "could not decode JSON body, invalid token #{inspect token} in body:\n\n#{body}"
    end
  end

  @doc """
  Returns the location header from the given redirect response.

  Raises if the response does not match the redirect status code
  (defaults to 302).

  ## Examples

      assert redirected_to(conn) =~ "/foo/bar"
      assert redirected_to(conn, 301) =~ "/foo/bar"
      assert redirected_to(conn, :moved_permanently) =~ "/foo/bar"
  """
  @spec redirected_to(Conn.t, status :: non_neg_integer) :: Conn.t
  def redirected_to(conn, status \\ 302)

  def redirected_to(%Conn{state: :unset}, _status) do
    raise "expected connection to have redirected but no response was set/sent"
  end

  def redirected_to(%Conn{status: status} = conn, status) do
    location = Conn.get_resp_header(conn, "location") |> List.first
    location || raise "no location header was set on redirected_to"
  end

  def redirected_to(conn, status) do
    raise "expected redirection with status #{status}, got: #{conn.status}"
  end

  @doc """
  Recycles the connection.

  Recycling receives an connection and returns a new connection,
  containing cookies and relevant information from the given one.

  This emulates behaviour performed by browsers where cookies
  returned in the response are available in following requests.

  Note `recycle/1` is automatically invoked when dispatching
  to the endpoint, unless the connection has already been
  recycled.
  """
  @spec recycle(Conn.t) :: Conn.t
  def recycle(conn) do
    conn()
    |> Plug.Test.recycle_cookies(conn)
    |> copy_headers(conn.req_headers, ~w(accept))
  end

  defp copy_headers(conn, headers, copy) do
    headers = for {k, v} <- headers, k in copy, do: {k, v}
    %{conn | req_headers: headers ++ conn.req_headers}
  end

  @doc """
  Ensures the connection is recycled if it wasn't already.

  See `recycle/1` for more information.
  """
  @spec recycle(Conn.t) :: Conn.t
  def ensure_recycled(conn) do
    if conn.private[:phoenix_recycled] do
      conn
    else
      recycle(conn)
    end
  end

  @doc """
  Calls the `@endpoint` and invokes router pipeline while bypassing route match.
  """
  defmacro bypass(conn) do
    quote bind_quoted: [conn: conn] do
      Phoenix.ConnTest.bypass_pipeline(conn, @endpoint)
    end
  end
  defmacro bypass(conn, router) do
    quote bind_quoted: [conn: conn, router: router] do
      Phoenix.ConnTest.bypass_pipeline(conn, @endpoint, router)
    end
  end
  defmacro bypass(conn, router, pipeline) do
    quote bind_quoted: [conn: conn, router: router, pipeline: pipeline] do
      Phoenix.ConnTest.bypass_pipeline(conn, @endpoint, router, pipeline)
    end
  end

  @doc """
  Calls the Endpoint and invokes router pipeline while bypassing route match.
  """
  @spec bypass_pipeline(Conn.t, Module.t) :: Conn.t
  def bypass_pipeline(conn, endpoint) do
    conn
    |> Plug.Conn.put_private(:phoenix_bypass, true)
    |> endpoint.call([])
  end
  @spec bypass_pipeline(Conn.t, Module.t, Module.t) :: Conn.t
  def bypass_pipeline(conn, endpoint, router) do
    conn
    |> Plug.Conn.put_private(:phoenix_bypass, router)
    |> endpoint.call([])
  end
  @spec bypass_pipeline(Conn.t, Module.t, Module.t, atom) :: Conn.t
  def bypass_pipeline(conn, endpoint, router, pipeline) do
    conn
    |> Plug.Conn.put_private(:phoenix_bypass, {router, pipeline})
    |> endpoint.call([])
  end
end
