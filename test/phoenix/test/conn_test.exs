defmodule Phoenix.Test.ConnTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

  defmodule Endpoint do
    def init(opts), do: opts
    def call(conn, opts), do: put_in(conn.private[:endpoint], opts)
  end

  @endpoint Endpoint

  test "conn/0 returns a new connection" do
    conn = conn()
    assert conn.method == "GET"
    assert conn.path_info == []
    assert conn.private.plug_skip_csrf_protection
    assert conn.private.phoenix_recycled
  end

  test "conn/2 returns a new connection" do
    conn = conn(:post, "/hello")
    assert conn.method == "POST"
    assert conn.path_info == ["hello"]
    assert conn.private.plug_skip_csrf_protection
    assert conn.private.phoenix_recycled
  end

  test "dispatch/5 with path" do
    conn = post conn(), "/hello", foo: "bar"
    assert conn.method == "POST"
    assert conn.path_info == ["hello"]
    assert conn.params == %{"foo" => "bar"}
    assert conn.private.endpoint == []
    refute conn.private.phoenix_recycled
  end

  test "dispatch/5 with action" do
    conn = post conn(), :hello, %{foo: "bar"}
    assert conn.method == "POST"
    assert conn.path_info == []
    assert conn.params == %{"foo" => "bar"}
    assert conn.private.endpoint == :hello
    refute conn.private.phoenix_recycled
  end

  test "dispatch/5 with binary body" do
    assert_raise ArgumentError, fn ->
      post conn(), :hello, "foo=bar"
    end

    conn =
      conn()
      |> put_req_header("content-type", "application/json")
      |> post(:hello, "[1, 2, 3]")
      |> Plug.Parsers.call(Plug.Parsers.init(parsers: [:json], json_decoder: Poison))

    assert conn.method == "POST"
    assert conn.path_info == []
    assert conn.params == %{"_json" => [1, 2, 3]}
  end

  test "dispatch/5 with recycling" do
    conn =
      conn()
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

  test "recycle/1" do
    conn =
      conn()
      |> get("/")
      |> put_req_header("hello", "world")
      |> put_req_cookie("req_cookie", "req_cookie")
      |> put_req_cookie("del_cookie", "del_cookie")
      |> put_req_cookie("over_cookie", "pre_cookie")
      |> put_resp_cookie("over_cookie", "pos_cookie")
      |> put_resp_cookie("resp_cookie", "resp_cookie")
      |> delete_resp_cookie("del_cookie")

    conn = conn |> recycle() |> fetch_cookies()
    assert get_req_header(conn, "hello") == []
    assert conn.cookies == %{"req_cookie"  => "req_cookie",
                             "over_cookie" => "pos_cookie",
                             "resp_cookie" => "resp_cookie"}
  end


  test "ensure_recycled/1" do
    conn =
      conn()
      |> put_req_header("hello", "world")
      |> ensure_recycled()
    assert get_req_header(conn, "hello") == ["world"]

    conn =
      put_in(conn.private.phoenix_recycled, false)
      |> ensure_recycled()
    assert get_req_header(conn, "hello") == []
  end

  test "put_req_header/3 and delete_req_header/3" do
    conn = conn(:get, "/")
    assert get_req_header(conn, "foo") == []

    conn = put_req_header(conn, "foo", "bar")
    assert get_req_header(conn, "foo") == ["bar"]

    conn = put_req_header(conn, "foo", "baz")
    assert get_req_header(conn, "foo") == ["baz"]

    conn = delete_req_header(conn, "foo")
    assert get_req_header(conn, "foo") == []
  end

  test "put_req_cookie/3 and delete_req_cookie/2" do
    conn = conn(:get, "/")
    assert get_req_header(conn, "cookie") == []

    conn = conn |> put_req_cookie("foo", "bar")
    assert get_req_header(conn, "cookie") == ["foo=bar"]

    conn = conn |> delete_req_cookie("foo")
    assert get_req_header(conn, "cookie") == []
  end

  test "response/2" do
    conn = conn(:get, "/")

    assert conn |> resp(200, "ok") |> response(200) == "ok"
    assert conn |> send_resp(200, "ok") |> response(200) == "ok"
    assert conn |> send_resp(200, "ok") |> response(:ok) == "ok"

    assert_raise RuntimeError,
                 ~r"expected connection to have a response but no response was set/sent", fn ->
      conn(:get, "/") |> response(200)
    end

    assert_raise RuntimeError,
                 "expected response with status 200, got: 404", fn ->
      conn(:get, "/") |> resp(404, "oops") |> response(200)
    end
  end

  test "html_response/2" do
    assert conn(:get, "/") |> put_resp_content_type("text/html")
                           |> resp(200, "ok") |> html_response(:ok) == "ok"

    assert_raise RuntimeError,
                 "no content-type was set, expected a html response", fn ->
      conn(:get, "/") |> resp(200, "ok") |> html_response(200)
    end
  end

  test "json_response/2" do
    assert conn(:get, "/") |> put_resp_content_type("application/json")
                           |> resp(200, "{}") |> json_response(:ok) == %{}

    assert_raise RuntimeError,
                 "no content-type was set, expected a json response", fn ->
      conn(:get, "/") |> resp(200, "ok") |> json_response(200)
    end

    assert_raise RuntimeError,
                 "could not decode JSON body, invalid token \"o\" in body:\n\nok", fn ->
      conn(:get, "/") |> put_resp_content_type("application/json")
                      |> resp(200, "ok") |> json_response(200)
    end
  end

  test "text_response/2" do
    assert conn(:get, "/") |> put_resp_content_type("text/plain")
                           |> resp(200, "ok") |> text_response(:ok) == "ok"

    assert_raise RuntimeError,
                 "no content-type was set, expected a text response", fn ->
      conn(:get, "/") |> resp(200, "ok") |> text_response(200)
    end
  end

  test "response_content_type/2" do
    conn = conn(:get, "/")

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
      conn(:get, "/")
      |> put_resp_header("location", "new location")
      |> send_resp(302, "foo")

    assert redirected_to(conn) == "new location"
  end

  test "redirected_to/2" do
    Enum.each 300..308, fn(status) ->
      conn =
        conn(:get, "/")
        |> put_resp_header("location", "new location")
        |> send_resp(status, "foo")

      assert redirected_to(conn, status) == "new location"
    end
  end

  test "redirected_to/2 without header" do
    assert_raise RuntimeError,
                 "no location header was set on redirected_to", fn ->
      assert conn(:get, "/")
      |> send_resp(302, "ok")
      |> redirected_to()
    end
  end

  test "redirected_to/2 without redirection" do
    assert_raise RuntimeError,
                 "expected redirection with status 302, got: 200", fn ->
      conn(:get, "/")
      |> put_resp_header("location", "new location")
      |> send_resp(200, "ok")
      |> redirected_to()
    end
  end

  test "redirected_to/2 without response" do
    assert_raise RuntimeError,
                 ~r"expected connection to have redirected but no response was set/sent", fn ->
      conn(:get, "/")
      |> redirected_to()
    end
  end
end
