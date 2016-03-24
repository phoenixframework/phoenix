defmodule Phoenix.Transports.TransportTest do
  use ExUnit.Case, async: true
  use RouterHelper

  alias Phoenix.Socket.Transport
  alias Phoenix.Socket.Message

  Application.put_env :phoenix, __MODULE__.Endpoint,
    force_ssl: [],
    url: [host: "host.com"],
    check_origin: ["//endpoint.com"]

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix
  end

  setup_all do
    Endpoint.start_link
    :ok
  end

  setup do
    Logger.disable(self())
  end

  ## on_exit_message

  test "on_exit_message/3" do
    assert Transport.on_exit_message("foo", "1", :normal) ==
           %Message{ref: "1", event: "phx_close", payload: %{}, topic: "foo"}
    assert Transport.on_exit_message("foo", "1", :shutdown) ==
           %Message{ref: "1", event: "phx_close", payload: %{}, topic: "foo"}
    assert Transport.on_exit_message("foo", "1", {:shutdown, :whatever}) ==
           %Message{ref: "1", event: "phx_close", payload: %{}, topic: "foo"}
    assert Transport.on_exit_message("foo", "1", :oops) ==
           %Message{ref: "1", event: "phx_error", payload: %{}, topic: "foo"}
  end

  ## Check origin

  defp check_origin(origin, opts) do
    conn = conn(:get, "/") |> put_req_header("origin", origin)
    Transport.check_origin(conn, make_ref(), Endpoint, opts)
  end

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

  test "allows invalid URIs" do
    origins = ["//example.com", "http://scheme.com", "//port.com:81"]

    for config <- [origins, false, true] do
      conn = check_origin("file://", check_origin: config)
      refute conn.halted
      conn = check_origin("", check_origin: config)
      refute conn.halted
    end
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

  ## force_ssl

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

  test "provides the protocol version" do
    assert Version.match?(Transport.protocol_version(), "~> 1.0")
  end
end
