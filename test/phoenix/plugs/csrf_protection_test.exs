defmodule Phoenix.Controller.CsrfProtectionTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias Phoenix.Plugs.CsrfProtection
  alias Phoenix.Plugs.CsrfProtection.InvalidAuthenticityToken

  @default_opts Plug.Session.init(
    store: :cookie,
    key: "foobar",
    encryption_salt: "cookie store encryption salt",
    signing_salt: "cookie store signing salt",
    encrypt: true
  )

  @secret String.duplicate("abcdef0123456789", 8)
  @csrf_token "hello123"

  def call_with_token(method, path, params \\ nil) do
    call(method, path, params)
    |> put_session(:csrf_token, @csrf_token)
    |> send_resp(200, "ok")
  end

  defp call(method, path, params \\ nil) do
    conn(method, path, params)
    |> sign_cookie(@secret)
    |> Plug.Session.call(@default_opts)
    |> fetch_session
  end

  defp recycle_data(conn, old_conn) do
    opts = Plug.Parsers.init(parsers: [:urlencoded, :multipart, :json], accept: ["*/*"])

    sign_cookie(conn, @secret)
    |> recycle(old_conn)
    |> Plug.Parsers.call(opts)
    |> Plug.Session.call(@default_opts)
    |> fetch_session
  end

  defp sign_cookie(conn, secret) do
    put_in conn.secret_key_base, secret
  end

  test "raise error for invalid authenticity token" do
    old_conn = call_with_token(:get, "/")

    assert_raise InvalidAuthenticityToken, fn ->
      conn(:post, "/", %{csrf_token: "foo"})
      |> recycle_data(old_conn)
      |> CsrfProtection.call([])
    end

    assert_raise InvalidAuthenticityToken, fn ->
      conn(:post, "/", %{})
      |> recycle_data(old_conn)
      |> CsrfProtection.call([])
    end
  end

  test "unprotected requests are always valid" do
    conn = call(:get, "/") |> CsrfProtection.call([])
    assert conn.halted == false

    conn = call(:options, "/") |> CsrfProtection.call([])
    assert conn.halted == false

    conn = call(:connect, "/") |> CsrfProtection.call([])
    assert conn.halted == false

    conn = call(:trace, "/") |> CsrfProtection.call([])
    assert conn.halted == false

    conn = call(:head, "/") |> CsrfProtection.call([])
    assert conn.halted == false
  end

  test "protected requests with valid token in params are allowed except DELETE" do
    old_conn = call_with_token(:get, "/")
    params = %{csrf_token: @csrf_token}

    conn = conn(:post, "/", params) |> recycle_data(old_conn) |> CsrfProtection.call([])
    assert conn.halted == false

    conn = conn(:put, "/", params) |> recycle_data(old_conn) |> CsrfProtection.call([])
    assert conn.halted == false

    conn = conn(:patch, "/", params) |> recycle_data(old_conn) |> CsrfProtection.call([])
    assert conn.halted == false
  end

  test "protected requests with valid token in header are allowed" do
    old_conn = call_with_token(:get, "/")

    conn = conn(:post, "/")
    |> recycle_data(old_conn)
    |> put_req_header("X-CSRF-Token", @csrf_token)
    |> CsrfProtection.call([])
    assert conn.halted == false

    conn = conn(:put, "/")
    |> recycle_data(old_conn)
    |> put_req_header("X-CSRF-Token", @csrf_token)
    |> CsrfProtection.call([])
    assert conn.halted == false

    conn = conn(:patch, "/")
    |> recycle_data(old_conn)
    |> put_req_header("X-CSRF-Token", @csrf_token)
    |> CsrfProtection.call([])
    assert conn.halted == false

    conn = conn(:delete, "/")
    |> recycle_data(old_conn)
    |> put_req_header("X-CSRF-Token", @csrf_token)
    |> CsrfProtection.call([])
    assert conn.halted == false
  end

  test "csrf_token is generated when it isn't available" do
    conn = call(:get, "/") |> CsrfProtection.call([])
    assert !!Conn.get_session(conn, :csrf_token)
  end
end
