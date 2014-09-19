defmodule Phoenix.Controller.CsrfProtectionTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias Phoenix.Plugs.CsrfProtection

  def simulate_request(method, path, params \\ nil) do
    simulate_request_without_token(method, path, params)
    |> put_session(:csrf_token, "hello123") |> send_resp(200, "ok")
  end

  defp session_options do
    Plug.Session.init(
      store: :cookie,
      key: "foobar",
      secret: "11111111111111111111111111111111111111111111111111111111111111111111111111")
  end

  defp simulate_request_without_token(method, path, params \\ nil) do
    conn(method, path, params)
    |> Plug.Session.call(session_options())
    |> fetch_session
  end

  defp recycle_data(conn, old_conn) do
    opts = Plug.Parsers.init(parsers: [:urlencoded, :multipart, Parsers.JSON], accept: ["*/*"])

    recycle(conn, old_conn)
    |> Plug.Parsers.call(opts)
    |> Plug.Session.call(session_options())
    |> fetch_session
  end

  test "for invalid authenticity token" do
    old_conn = simulate_request(:get, "/")

    conn = conn(:post, "/", %{csrf_token: "foo"})
           |> recycle_data(old_conn)
           |> CsrfProtection.call([])

    assert conn.state == :sent
    assert conn.halted == true

    conn = conn(:post, "/", %{})
           |> recycle_data(old_conn)
           |> CsrfProtection.call([])

    assert conn.state == :sent
    assert conn.halted == true
  end

  test "unprotected requests are always valid" do
    conn = simulate_request_without_token(:get, "/") |> CsrfProtection.call([])
    assert conn.halted  == false

    conn = simulate_request_without_token(:options, "/") |> CsrfProtection.call([])
    assert conn.halted  == false

    conn = simulate_request_without_token(:connect, "/") |> CsrfProtection.call([])
    assert conn.halted == false

    conn = simulate_request_without_token(:trace, "/") |> CsrfProtection.call([])
    assert conn.halted == false

    conn = simulate_request_without_token(:head, "/") |> CsrfProtection.call([])
    assert conn.halted == false
  end

  test "protected requests with valid token in params are allowed except DELETE" do
    old_conn = simulate_request(:get, "/")
    params = %{csrf_token: "hello123"}

    conn = conn(:post, "/", params) |> recycle_data(old_conn) |> CsrfProtection.call([])
    assert conn.halted == false

    conn = conn(:put, "/", params) |> recycle_data(old_conn) |> CsrfProtection.call([])
    assert conn.halted == false

    conn = conn(:patch, "/", params) |> recycle_data(old_conn) |> CsrfProtection.call([])
    assert conn.halted == false
  end

  test "protected requests with valid token in header are allowed" do
    old_conn = simulate_request(:get, "/")

    conn = conn(:post, "/")
    |> recycle_data(old_conn)
    |> put_req_header("X-CSRF-Token", "hello123")
    |> CsrfProtection.call([])
    assert conn.halted == false

    conn = conn(:put, "/")
    |> recycle_data(old_conn)
    |> put_req_header("X-CSRF-Token", "hello123")
    |> CsrfProtection.call([])
    assert conn.halted == false

    conn = conn(:patch, "/")
    |> recycle_data(old_conn)
    |> put_req_header("X-CSRF-Token", "hello123")
    |> CsrfProtection.call([])
    assert conn.halted == false

    conn = conn(:delete, "/")
    |> recycle_data(old_conn)
    |> put_req_header("X-CSRF-Token", "hello123")
    |> CsrfProtection.call([])
    assert conn.halted == false
  end

  test "csrf_token is generated when it isn't available" do
    conn = simulate_request_without_token(:get, "/") |> CsrfProtection.call([])
    assert !!Conn.get_session(conn, :csrf_token)
  end
end
