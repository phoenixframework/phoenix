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

  ## heartbeat_message

  test "heartbeat_message/2" do
    assert Transport.heartbeat_message() ==
           %Message{event: "heartbeat", payload: %{}, topic: "phoenix"}
  end

  ## on_exit_message

  test "on_exit_message/2" do
    assert Transport.on_exit_message("foo", :normal) ==
           %Message{event: "phx_close", payload: %{}, topic: "foo"}
    assert Transport.on_exit_message("foo", :shutdown) ==
           %Message{event: "phx_close", payload: %{}, topic: "foo"}
    assert Transport.on_exit_message("foo", {:shutdown, :whatever}) ==
           %Message{event: "phx_close", payload: %{}, topic: "foo"}
    assert Transport.on_exit_message("foo", :oops) ==
           %Message{event: "phx_error", payload: %{}, topic: "foo"}
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

  test "checks the origin of requests against allowed origins" do
    origins = ["//example.com", "http://scheme.com", "//port.com:81"]

    # Completely invalid
    conn = check_origin("http://notallowed.com/", check_origin: origins)
    assert conn.halted
    assert conn.status == 403

    conn = check_origin("", check_origin: origins)
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
