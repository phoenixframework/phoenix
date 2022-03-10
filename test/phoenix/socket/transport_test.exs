defmodule Phoenix.Socket.TransportTest do
  use ExUnit.Case, async: true
  use RouterHelper

  import ExUnit.CaptureLog

  alias Phoenix.Socket.Transport

  @secret_key_base String.duplicate("abcdefgh", 8)

  Application.put_env :phoenix, __MODULE__.Endpoint,
    force_ssl: [],
    url: [host: "host.com"],
    check_origin: ["//endpoint.com"],
    secret_key_base: @secret_key_base

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix

    @session_config [
      store: :cookie,
      key: "_hello_key",
      signing_salt: "change_me"
    ]

    def session_config, do: @session_config

    plug Plug.Session, @session_config
    plug :fetch_session
    plug Plug.CSRFProtection
    plug :put_session

    defp put_session(conn, _) do
      conn
      |> put_session(:from_session, "123")
      |> send_resp(200, Plug.CSRFProtection.get_csrf_token())
    end
  end

  setup_all do
    Endpoint.start_link()
    :ok
  end

  setup do
    Logger.disable(self())
  end

  ## Check origin

  describe "check_origin/4" do
    defp check_origin(%Plug.Conn{} = conn, origin, opts) do
      conn = put_req_header(conn, "origin", origin)
      Transport.check_origin(conn, make_ref(), Endpoint, opts)
    end

    defp check_origin(origin, opts), do: check_origin(conn(:get, "/"), origin, opts)

    test "does not check origin if disabled" do
      refute check_origin("/", check_origin: false).halted
    end

    test "checks origin against host" do
      refute check_origin("https://host.com/", check_origin: true).halted
      conn = check_origin("https://another.com/", check_origin: true)
      assert conn.halted
      assert conn.status == 403
    end

    test "checks origin from endpoint config" do
      refute check_origin("https://endpoint.com/", []).halted
      conn = check_origin("https://another.com/", [])
      assert conn.halted
      assert conn.status == 403
    end

    test "can get the host from system variables" do
      refute check_origin("https://host.com", check_origin: true).halted
    end

    test "wildcard subdomains" do
      origins = ["https://*.ex.com", "http://*.ex.com"]

      conn = check_origin("http://org1.ex.com", check_origin: origins)
      refute conn.halted
      conn = check_origin("https://org1.ex.com", check_origin: origins)
      refute conn.halted
    end

    test "nested wildcard subdomains" do
      origins = ["http://*.foo.example.com"]

      conn = check_origin("http://org1.foo.example.com", check_origin: origins)
      refute conn.halted

      conn = check_origin("http://org1.bar.example.com", check_origin: origins)
      assert conn.halted
      assert conn.status == 403
    end

    test "subdomains do not match without a wildcard" do
      conn = check_origin("http://org1.ex.com", check_origin: ["//ex.com"])
      assert conn.halted
    end

    test "halts invalid URIs when check origin is configured" do
      Logger.enable(self())
      origins = ["//example.com", "http://scheme.com", "//port.com:81"]

      logs =
        capture_log(fn ->
          for config <- [origins, true] do
            assert check_origin("file://", check_origin: config).halted
            assert check_origin("null", check_origin: config).halted
            assert check_origin("", check_origin: config).halted
          end
        end)

      assert logs =~ "Origin of the request: file://"
      assert logs =~ "Origin of the request: null"
    end

    def invalid_allowed?(%URI{host: nil}), do: true
    def invalid_allowed?(%URI{host: ""}), do: true

    test "allows custom MFA check to handle invalid host" do
      mfa = {__MODULE__, :invalid_allowed?, []}

      refute check_origin("file://", check_origin: mfa).halted
      refute check_origin("null", check_origin: mfa).halted
      refute check_origin("", check_origin: mfa).halted
    end

    test "checks origin against :conn" do
      conn = %Plug.Conn{conn(:get, "/") | host: "example.com", scheme: :http, port: 80}
      refute check_origin(conn, "http://example.com", check_origin: :conn).halted

      assert check_origin(conn, "https://example.com", check_origin: :conn).halted
      assert check_origin(conn, "ws://example.com", check_origin: :conn).halted
      assert check_origin(conn, "wss://example.com", check_origin: :conn).halted
      assert check_origin(conn, "http://www.example.com", check_origin: :conn).halted
      assert check_origin(conn, "http://www.another.com", check_origin: :conn).halted

      conn = %Plug.Conn{conn(:get, "/") | host: "example.com", scheme: :https, port: 443}
      refute check_origin(conn, "https://example.com", check_origin: :conn).halted
      assert check_origin(conn, "http://example.com", check_origin: :conn).halted
      assert check_origin(conn, "https://example.com:4000", check_origin: :conn).halted
    end

    test "does not halt invalid URIs when check_origin is disabled" do
      refute check_origin("file://", check_origin: false).halted
      refute check_origin("null", check_origin: false).halted
      refute check_origin("", check_origin: false).halted
    end

    test "checks the origin of requests against allowed origins" do
      origins = ["//example.com", "http://scheme.com", "//port.com:81"]

      # not allowed host
      conn = check_origin("http://notallowed.com/", check_origin: origins)
      assert conn.halted
      assert conn.status == 403

      # Only host match
      refute check_origin("http://example.com/", check_origin: origins).halted
      refute check_origin("https://example.com/", check_origin: origins).halted

      # Scheme + host match (checks port due to scheme)
      refute check_origin("http://scheme.com/", check_origin: origins).halted

      conn = check_origin("https://scheme.com/", check_origin: origins)
      assert conn.halted
      assert conn.status == 403

      conn = check_origin("http://scheme.com:8080/", check_origin: origins)
      assert conn.halted
      assert conn.status == 403

      # Scheme + host + port match
      refute check_origin("http://port.com:81/", check_origin: origins).halted

      conn = check_origin("http://port.com:82/", check_origin: origins)
      assert conn.halted
      assert conn.status == 403
    end

    def check_origin_callback(%URI{host: "example.com"}), do: true
    def check_origin_callback(%URI{host: _}), do: false

    test "checks the origin of requests against an MFA" do
      # callback without additional arguments
      mfa = {__MODULE__, :check_origin_callback, []}

      # a not allowed host
      conn = check_origin("http://notallowed.com/", check_origin: mfa)
      assert conn.halted
      assert conn.status == 403

      # an allowed host
      refute check_origin("http://example.com/", check_origin: mfa).halted
    end

    def check_origin_additional(%URI{host: allowed}, allowed), do: true
    def check_origin_additional(%URI{host: _}, _allowed), do: false

    test "checks the origin of requests against an MFA, passing additional arguments" do
      # callback with additional argument
      mfa = {__MODULE__, :check_origin_additional, ["host.com"]}

      # a not allowed host
      conn = check_origin("http://notallowed.com/", check_origin: mfa)
      assert conn.halted
      assert conn.status == 403

      # an allowed host
      refute check_origin("https://host.com/", check_origin: mfa).halted
    end
  end

  ## Check subprotocols

  describe "check_subprotocols/2" do
    defp check_subprotocols(expected, passed) do
      conn = conn(:get, "/") |> put_req_header("sec-websocket-protocol", Enum.join(passed, ", "))
      Transport.check_subprotocols(conn, expected)
    end

    test "does not check subprotocols if not passed expected" do
      refute check_subprotocols(nil, ["sip"]).halted
    end

    test "does not check subprotocols if conn is halted" do
      halted_conn = conn(:get, "/") |> halt()
      conn = Transport.check_subprotocols(halted_conn, ["sip"])
      assert conn == halted_conn
    end

    test "returns first matched subprotocol" do
      conn = check_subprotocols(["sip", "mqtt"], ["sip", "mqtt"])
      refute conn.halted
      assert get_resp_header(conn, "sec-websocket-protocol") == ["sip"]
    end

    test "halt if expected and passed subprotocols don't match" do
      conn = check_subprotocols(["sip"], ["mqtt"])
      assert conn.halted
      assert conn.status == 403
    end

    test "halt if expected subprotocols passed in the wrong format" do
      conn = check_subprotocols("sip", ["mqtt"])
      assert conn.halted
      assert conn.status == 403
    end
  end

  describe "force_ssl/4" do
    test "forces SSL" do
      # Halts
      conn = Transport.force_ssl(conn(:get, "http://foo.com/"), make_ref(), Endpoint, [])
      assert conn.halted
      assert get_resp_header(conn, "location") == ["https://host.com/"]

      # Disabled
      conn = Transport.force_ssl(conn(:get, "http://foo.com/"), make_ref(), Endpoint, force_ssl: false)
      refute conn.halted

      # No-op when already halted
      conn = Transport.force_ssl(conn(:get, "http://foo.com/") |> halt(), make_ref(), Endpoint, [])
      assert conn.halted
      assert get_resp_header(conn, "location") == []

      # Valid
      conn = Transport.force_ssl(conn(:get, "https://foo.com/"), make_ref(), Endpoint, [])
      refute conn.halted
    end
  end

  describe "connect_info/3" do
    defp load_connect_info(connect_info) do
      [connect_info: connect_info] = Transport.load_config(connect_info: connect_info)
      connect_info
    end

    test "loads the session from MFA" do
      conn = conn(:get, "https://foo.com/") |> Endpoint.call([])
      csrf_token = conn.resp_body
      session_cookie = conn.cookies["_hello_key"]

      connect_info = load_connect_info(session: {Endpoint, :session_config, []})

      assert %{session: %{"from_session" => "123"}} =
               conn(:get, "https://foo.com/", _csrf_token: csrf_token)
               |> put_req_cookie("_hello_key", session_cookie)
               |> fetch_query_params()
               |> Transport.connect_info(Endpoint, connect_info)
    end
  end
end
