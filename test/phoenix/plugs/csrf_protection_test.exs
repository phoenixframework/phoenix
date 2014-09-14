defmodule Phoenix.Controller.CsrfProtectionTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias Phoenix.Plugs.CsrfProtection

  def simulate_request(method, path, params \\ nil) do
    opts = Plug.Parsers.init(parsers: [:urlencoded, :multipart, Parsers.JSON], accept: ["*/*"])
    conn = conn(method, path, params)
           |> fetch_cookies
           |> Plug.Parsers.call(opts)
    opts = Plug.Session.init(store: :cookie, key: "foobar", secret: "11111111111111111111111111111111111111111111111111111111111111111111111111")
    Plug.Session.call(conn, opts)
    |> fetch_session
    |> put_session(:csrf_token, "hello123")
  end

  setup do
    conn = simulate_request(:get, "/")
    assert get_session(conn, :csrf_token) == "hello123"
    :ok
  end

  test "raises error for invalid authenticity token" do
    assert_raise RuntimeError, fn ->
      conn = simulate_request(:post, "/", %{first_name: "Foo", csrf_token: "foo"})
      assert get_session(conn, :csrf_token) == "hello123"
      CsrfProtection.call(conn, [])
    end
    assert_raise RuntimeError, fn ->
      conn = simulate_request(:post, "/", %{first_name: "Foo", csrf_token: "foo"})
      assert get_session(conn, :csrf_token) == "hello123"
      CsrfProtection.call(conn, [])
    end
  end

  test "unprotected requests are always valid" do
    simulate_request(:get, "/") |> CsrfProtection.call([])
    simulate_request(:options, "/") |> CsrfProtection.call([])
    simulate_request(:connect, "/") |> CsrfProtection.call([])
    simulate_request(:trace, "/") |> CsrfProtection.call([])
    simulate_request(:head, "/") |> CsrfProtection.call([])
  end

  test "protected requests with valid token in params are allowed except DELETE" do
    simulate_request(:post, "/", %{csrf_token: "hello123"}) |> CsrfProtection.call([])
    simulate_request(:put, "/", %{csrf_token: "hello123"}) |> CsrfProtection.call([])
    simulate_request(:patch, "/", %{csrf_token: "hello123"}) |> CsrfProtection.call([])
  end

  test "protected requests with valid token in header are allowed" do
    simulate_request(:post, "/")
    |> put_req_header("X-CSRF-Token", "hello123")
    |> CsrfProtection.call([])
    simulate_request(:put, "/")
    |> put_req_header("X-CSRF-Token", "hello123")
    |> CsrfProtection.call([])
    simulate_request(:patch, "/")
    |> put_req_header("X-CSRF-Token", "hello123")
    |> CsrfProtection.call([])
    simulate_request(:delete, "/")
    |> put_req_header("X-CSRF-Token", "hello123")
    |> CsrfProtection.call([])
  end
end
