defmodule Phoenix.Test.ConnTest.CatchAll do
  def init(opts), do: opts
  def call(conn, :stat), do: conn.params["action"].(conn)
  def call(conn, _opts), do: Plug.Conn.assign(conn, :catch_all, true)
end

defmodule Phoenix.Test.ConnTest.RedirRouter do
  use Phoenix.Router
  alias Phoenix.Test.ConnTest.CatchAll

  get "/", CatchAll, :foo
  get "/posts/:id", SomeController, :some_action
end

defmodule Phoenix.Test.ConnTest.Router do
  use Phoenix.Router
  alias Phoenix.Test.ConnTest.CatchAll

  pipeline :browser do
    plug :put_bypass, :browser
  end

  pipeline :api do
    plug :put_bypass, :api
  end

  scope "/" do
    pipe_through :browser
    get "/stat", CatchAll, :stat
    forward "/", CatchAll
  end

  def put_bypass(conn, pipeline) do
    bypassed = (conn.assigns[:bypassed] || []) ++ [pipeline]
    Plug.Conn.assign(conn, :bypassed, bypassed)
  end
end

defmodule Phoenix.Test.ConnTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest
  alias Phoenix.Test.ConnTest.{Router, RedirRouter}

  defmodule ConnError do
    defexception [message: nil, plug_status: 500]
  end

  Application.put_env(:phoenix, Phoenix.Test.ConnTest.Endpoint, [])

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix
    def init(opts), do: opts
    def call(conn, :set), do: resp(conn, 200, "ok")
    def call(conn, opts) do
      put_in(super(conn, opts).private[:endpoint], opts)
      |> Router.call(Router.init([]))
    end
  end

  @endpoint Endpoint

  setup_all do
    Endpoint.start_link()
    :ok
  end

  test "build_conn/0 returns a new connection" do
    conn = build_conn()
    assert conn.method == "GET"
    assert conn.path_info == []
    assert conn.private.plug_skip_csrf_protection
    assert conn.private.phoenix_recycled
  end

  test "build_conn/2 returns a new connection" do
    conn = build_conn(:post, "/hello")
    assert conn.method == "POST"
    assert conn.path_info == ["hello"]
    assert conn.private.plug_skip_csrf_protection
    assert conn.private.phoenix_recycled
  end

  test "dispatch/5 with path" do
    conn = post build_conn(), "/hello", foo: "bar"
    assert conn.method == "POST"
    assert conn.path_info == ["hello"]
    assert conn.params == %{"foo" => "bar"}
    assert conn.private.endpoint == []
    refute conn.private.phoenix_recycled
  end

  test "dispatch/5 with action" do
    conn = post build_conn(), :hello, %{foo: "bar"}
    assert conn.method == "POST"
    assert conn.path_info == []
    assert conn.params == %{"foo" => "bar"}
    assert conn.private.endpoint == :hello
    refute conn.private.phoenix_recycled
  end

  test "dispatch/5 with binary body" do
    assert_raise ArgumentError, fn ->
      post build_conn(), :hello, "foo=bar"
    end

    conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> post(:hello, "[1, 2, 3]")
      |> Plug.Parsers.call(Plug.Parsers.init(parsers: [:json], json_decoder: Phoenix.json_library()))

    assert conn.method == "POST"
    assert conn.path_info == []
    assert conn.params == %{"_json" => [1, 2, 3]}
  end

  test "dispatch/5 with recycling" do
    conn =
      build_conn()
      |> put_req_header("hello", "world")
      |> post(:hello)
    assert get_req_header(conn, "hello") == ["world"]

    conn =
      conn
      |> put_req_header("hello", "skipped")
      |> post(:hello)
    assert get_req_header(conn, "hello") == []

    conn =
      conn
      |> recycle()
      |> put_req_header("hello", "world")
      |> post(:hello)
    assert get_req_header(conn, "hello") == ["world"]
  end

  test "dispatch/5 with :set state automatically sends" do
    conn = get build_conn(), :set
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body == "ok"
    refute conn.private.phoenix_recycled
  end

  describe "recycle/1" do
    test "relevant request headers are persisted" do
      conn =
        build_conn()
        |> get("/")
        |> put_req_header("accept", "text/html")
        |> put_req_header("authorization", "Bearer mytoken")
        |> put_req_header("hello", "world")

      conn = conn |> recycle()
      assert get_req_header(conn, "accept") == ["text/html"]
      assert get_req_header(conn, "authorization") == ["Bearer mytoken"]
      assert get_req_header(conn, "hello") == []
    end

    test "host is persisted" do
      conn =
        build_conn(:get, "http://localhost/", nil)
        |> recycle()
      assert conn.host == "localhost"
    end

    test "cookies are persisted" do
      conn =
        build_conn()
        |> get("/")
        |> put_req_cookie("req_cookie", "req_cookie")
        |> put_req_cookie("del_cookie", "del_cookie")
        |> put_req_cookie("over_cookie", "pre_cookie")
        |> put_resp_cookie("over_cookie", "pos_cookie")
        |> put_resp_cookie("resp_cookie", "resp_cookie")
        |> delete_resp_cookie("del_cookie")

      conn = conn |> recycle() |> fetch_cookies()
      assert conn.cookies == %{"req_cookie"  => "req_cookie",
                               "over_cookie" => "pos_cookie",
                               "resp_cookie" => "resp_cookie"}
    end
  end

  test "ensure_recycled/1" do
    conn =
      build_conn()
      |> put_req_header("hello", "world")
      |> ensure_recycled()
    assert get_req_header(conn, "hello") == ["world"]

    conn =
      put_in(conn.private.phoenix_recycled, false)
      |> ensure_recycled()
    assert get_req_header(conn, "hello") == []
  end

  test "put_req_header/3 and delete_req_header/3" do
    conn = build_conn(:get, "/")
    assert get_req_header(conn, "foo") == []

    conn = put_req_header(conn, "foo", "bar")
    assert get_req_header(conn, "foo") == ["bar"]

    conn = put_req_header(conn, "foo", "baz")
    assert get_req_header(conn, "foo") == ["baz"]

    conn = delete_req_header(conn, "foo")
    assert get_req_header(conn, "foo") == []
  end

  test "put_req_cookie/3 and delete_req_cookie/2" do
    conn = build_conn(:get, "/")
    assert get_req_header(conn, "cookie") == []

    conn = conn |> put_req_cookie("foo", "bar")
    assert get_req_header(conn, "cookie") == ["foo=bar"]

    conn = conn |> delete_req_cookie("foo")
    assert get_req_header(conn, "cookie") == []
  end

  test "response/2" do
    conn = build_conn(:get, "/")

    assert conn |> resp(200, "ok") |> response(200) == "ok"
    assert conn |> send_resp(200, "ok") |> response(200) == "ok"
    assert conn |> send_resp(200, "ok") |> response(:ok) == "ok"

    assert_raise RuntimeError,
                 ~r"expected connection to have a response but no response was set/sent", fn ->
      build_conn(:get, "/") |> response(200)
    end

    assert_raise RuntimeError,
                 "expected response with status 200, got: 404, with body:\noops", fn ->
      build_conn(:get, "/") |> resp(404, "oops") |> response(200)
    end
  end

  test "html_response/2" do
    assert build_conn(:get, "/") |> put_resp_content_type("text/html")
                           |> resp(200, "ok") |> html_response(:ok) == "ok"

    assert_raise RuntimeError,
                 "no content-type was set, expected a html response", fn ->
      build_conn(:get, "/") |> resp(200, "ok") |> html_response(200)
    end
  end

  test "json_response/2" do
    assert build_conn(:get, "/") |> put_resp_content_type("application/json")
                           |> resp(200, "{}") |> json_response(:ok) == %{}

    assert build_conn(:get, "/") |> put_resp_content_type("application/vnd.api+json")
                           |> resp(200, "{}") |> json_response(:ok) == %{}

    assert build_conn(:get, "/") |> put_resp_content_type("application/vnd.collection+json")
                           |> resp(200, "{}") |> json_response(:ok) == %{}

    assert build_conn(:get, "/") |> put_resp_content_type("application/vnd.hal+json")
                           |> resp(200, "{}") |> json_response(:ok) == %{}

    assert build_conn(:get, "/") |> put_resp_content_type("application/ld+json")
                           |> resp(200, "{}") |> json_response(:ok) == %{}

    assert_raise RuntimeError,
                 "no content-type was set, expected a json response", fn ->
      build_conn(:get, "/") |> resp(200, "ok") |> json_response(200)
    end

    assert_raise Jason.DecodeError,
                 "unexpected byte at position 0: 0x6F ('o')", fn ->
      build_conn(:get, "/") |> put_resp_content_type("application/json")
                      |> resp(200, "ok") |> json_response(200)
    end

    assert_raise Jason.DecodeError, ~r/unexpected end of input at position 0/, fn ->
      build_conn(:get, "/")
      |> put_resp_content_type("application/json")
      |> resp(200, "")
      |> json_response(200)
    end

    assert_raise RuntimeError, ~s(expected response with status 200, got: 400, with body:\n{"error": "oh oh"}), fn ->
      build_conn(:get, "/")
      |> put_resp_content_type("application/json")
      |> resp(400, ~s({"error": "oh oh"}))
      |> json_response(200)
    end
  end

  test "text_response/2" do
    assert build_conn(:get, "/") |> put_resp_content_type("text/plain")
                           |> resp(200, "ok") |> text_response(:ok) == "ok"

    assert_raise RuntimeError,
                 "no content-type was set, expected a text response", fn ->
      build_conn(:get, "/") |> resp(200, "ok") |> text_response(200)
    end
  end

  test "response_content_type/2" do
    conn = build_conn(:get, "/")

    assert put_resp_content_type(conn, "text/html") |> response_content_type(:html) ==
           "text/html; charset=utf-8"
    assert put_resp_content_type(conn, "text/plain") |> response_content_type(:text) ==
           "text/plain; charset=utf-8"
    assert put_resp_content_type(conn, "application/json") |> response_content_type(:json) ==
           "application/json; charset=utf-8"

    assert_raise RuntimeError,
                 "no content-type was set, expected a html response", fn ->
      conn |> response_content_type(:html)
    end

    assert_raise RuntimeError,
                 "expected content-type for html, got: \"text/plain; charset=utf-8\"", fn ->
      put_resp_content_type(conn, "text/plain") |> response_content_type(:html)
    end
  end

  test "redirected_to/1" do
    conn =
      build_conn(:get, "/")
      |> put_resp_header("location", "new location")
      |> send_resp(302, "foo")

    assert redirected_to(conn) == "new location"
  end

  test "redirected_to/2" do
    Enum.each 300..308, fn(status) ->
      conn =
        build_conn(:get, "/")
        |> put_resp_header("location", "new location")
        |> send_resp(status, "foo")

      assert redirected_to(conn, status) == "new location"
    end
  end

  test "redirected_to/2 with status atom" do
    conn =
      build_conn(:get, "/")
      |> put_resp_header("location", "new location")
      |> send_resp(301, "foo")

    assert redirected_to(conn, :moved_permanently) == "new location"
  end

  test "redirected_to/2 without header" do
    assert_raise RuntimeError,
                 "no location header was set on redirected_to", fn ->
      assert build_conn(:get, "/")
      |> send_resp(302, "ok")
      |> redirected_to()
    end
  end

  test "redirected_to/2 without redirection" do
    assert_raise RuntimeError,
                 "expected redirection with status 302, got: 200", fn ->
      build_conn(:get, "/")
      |> put_resp_header("location", "new location")
      |> send_resp(200, "ok")
      |> redirected_to()
    end
  end

  test "redirected_to/2 without response" do
    assert_raise RuntimeError,
                 ~r"expected connection to have redirected but no response was set/sent", fn ->
      build_conn(:get, "/")
      |> redirected_to()
    end
  end

  describe "redirected_params/1" do
    test "with matching route" do
      conn =
        build_conn(:get, "/")
        |> RedirRouter.call(RedirRouter.init([]))
        |> put_resp_header("location", "/posts/123")
        |> send_resp(302, "foo")

      assert redirected_params(conn) == %{id: "123"}
    end

    test "raises Phoenix.Router.NoRouteError for unmatched location" do
      conn =
        build_conn(:get, "/")
        |> RedirRouter.call(RedirRouter.init([]))
        |> put_resp_header("location", "/unmatched")
        |> send_resp(302, "foo")

      assert_raise Phoenix.Router.NoRouteError, fn ->
        redirected_params(conn)
      end
    end

    test "without redirection" do
      assert_raise RuntimeError,
                  "expected redirection with status 302, got: 200", fn ->
        build_conn(:get, "/")
        |> RedirRouter.call(RedirRouter.init([]))
        |> put_resp_header("location", "new location")
        |> send_resp(200, "ok")
        |> redirected_params()
      end
    end
  end

  test "bypass_through/3 bypasses route match and invokes pipeline" do
    conn = get(build_conn(), "/")
    assert conn.assigns[:catch_all]

    conn =
      build_conn()
      |> bypass_through(Router, :browser)
      |> get("/")

    assert conn.assigns[:bypassed] == [:browser]
    refute conn.assigns[:catch_all]

    conn =
      build_conn()
      |> bypass_through(Router, [:api])
      |> get("/")

    assert conn.assigns[:bypassed] == [:api]
    refute conn.assigns[:catch_all]

    conn =
      build_conn()
      |> bypass_through(Router, [:browser, :api])
      |> get("/")

    assert conn.assigns[:bypassed] == [:browser, :api]
    refute conn.assigns[:catch_all]
  end

  test "bypass_through/2 bypasses route match" do
    conn =
      build_conn()
      |> bypass_through(Router, [])
      |> get("/")
    refute conn.assigns[:catch_all]
  end

  test "bypass_through/1 bypasses router" do
    conn =
      build_conn()
      |> bypass_through()
      |> get("/")

    refute conn.assigns[:catch_all]
  end

  test "assert_error_sent/2 with expected error response" do
    response = assert_error_sent :not_found, fn ->
      get(build_conn(), "/stat", action: fn _ -> raise ConnError, plug_status: 404 end)
    end
    assert {404, [_h | _t], "404.html from Phoenix.ErrorView"} = response

    response = assert_error_sent 400, fn ->
      get(build_conn(), "/stat", action: fn _ -> raise ConnError, plug_status: 400 end)
    end
    assert {400, [_h | _t], "400.html from Phoenix.ErrorView"} = response
  end

  test "assert_error_sent/2 with status mismatch assertion" do
    assert_raise ExUnit.AssertionError, ~r/expected error to be sent as 400 status, but got 500 from.*RuntimeError/s, fn ->
      assert_error_sent 400, fn ->
        get(build_conn(), "/stat", action: fn _conn -> raise RuntimeError end)
      end
    end
  end

  test "assert_error_sent/2 with no error" do
    assert_raise ExUnit.AssertionError, ~r/expected error to be sent as 404 status, but no error happened/, fn ->
      assert_error_sent 404, fn -> get(build_conn(), "/") end
    end
  end

  test "assert_error_sent/2 with error but no response" do
    assert_raise ExUnit.AssertionError, ~r/expected error to be sent as 404 status, but got an error with no response from.*RuntimeError/s, fn ->
      assert_error_sent 404, fn -> raise "oops" end
    end
  end

  test "assert_error_sent/2 with response but no error" do
    assert_raise ExUnit.AssertionError, ~r/expected error to be sent as 400 status, but response sent 400 without error/, fn ->
      assert_error_sent :bad_request, fn ->
        get(build_conn(), "/stat", action: fn conn -> Plug.Conn.send_resp(conn, 400, "") end)
      end
    end
  end

  for method <- [:get, :post, :put, :delete] do
    @method method
    test "#{method} helper raises ArgumentError for mismatched conn" do
      assert_raise ArgumentError, ~r/expected first argument to #{@method} to be/, fn ->
        unquote(@method)("/foo/bar", %{baz: "baz"})
      end
    end
  end
end
