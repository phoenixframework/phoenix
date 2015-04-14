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

  test "dispatch/5 with reclying" do
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

  test "redirected_to/1" do
    Enum.each 300..308, fn(status) ->
      conn = conn(:get, "/")
              |> put_resp_header("Location", "new location")
              |> send_resp(status, "foo")

      assert redirected_to(conn) == ["new location"]
    end

    conn = conn(:get, "/")
           |> send_resp(200, "foo")

    assert_raise ArgumentError, fn ->
      redirected_to(conn)
    end
  end
end
