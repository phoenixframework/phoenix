defmodule Phoenix.ConnTest do
  @doc """
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
      |> put_req_header("accepts", "application/json")
      |> get("/")

  The endpoint being tested is accessed via the `@endpoint` module
  attribute.

  ## Controller testing

  The functions in this module can also be used for controller
  testing. While not the default way of testing in Phoenix
  applications, it may be handful in some situations.

  For such cases, just pass an atom representing the action
  to dispatch:

      conn = get conn(), :index
      assert conn.resp_body =~ "Welcome!"

  ## Views testing

  Under other circunstances, you may be testing a view or
  another layer that requires a connection for processing.
  For such cases, a connection can be created using the
  `conn/3` helper:

      MyApp.UserView.render "hello.html",
                             conn: conn(:get, "/")

  ## Reclying

  Browsers implement a storage by using cookies. When a cookie
  is set in the response, the browser stores it and sends it in
  the next request.

  To emulate this behaviour, this module provides the idea of
  recyling. The `recycle/1` function receives a connection and
  returns a new connection, similar to the one returned by
  `conn/0` with all the response cookies from the previous
  connection defined as request headers. This is useful when
  testing multiple routes that require cookies or session to
  work.

  Keep in mind Phoenix will automatically recycle the connection
  between dispatches. This usually works out well most times but
  it may discard information if you are modifying the connection
  before the next dispatch:

      # No reclycling as the connection is fresh
      conn = get conn(), "/"

      # The connection is recycled, creating a new one behind the scenes
      conn = post conn, "/login"

      # We can also recycle manually in case we want custom headers
      conn = recycle(conn)
      conn = put_req_header("x-special", "nice")

      # No reclycling as we did it explicitly
      conn = delete conn, "/logout"

  Reclying also recycles the "accept" header.
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

  This function, as well as `get/3`, `post/3` and friends, accept the
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

  @doc """
  Puts a new request header.

  Previous entries of the same header are overridden.
  """
  @spec put_req_header(Conn.t, binary, binary) :: Conn.t
  defdelegate put_req_header(conn, key, value), to: Plug.Test

  @doc """
  Deletes a request header.
  """
  @spec delete_req_header(Conn.t, binary) :: Conn.t
  defdelegate delete_req_header(conn, key), to: Plug.Test

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
  Puts the given value udner key in the flash storage.
  """
  @spec put_flash(Conn.t, term, term) :: Conn.t
  defdelegate put_flash(conn, key, value), to: Phoenix.Controller

  @doc """
  Clears up the flash storage.
  """
  @spec clear_flash(Conn.t) :: Conn.t
  defdelegate clear_flash(conn), to: Phoenix.Controller

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
    %{conn | req_headers: headers}
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
end
