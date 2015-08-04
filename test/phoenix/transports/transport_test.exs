defmodule Phoenix.Transports.TransportTest do
  use ExUnit.Case, async: true
  use RouterHelper

  alias Phoenix.Socket.Transport
  alias Phoenix.Socket.Message

  Application.put_env :phoenix, __MODULE__.Endpoint,
    force_ssl: [],
    url: [host: "host.com"]

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix
  end

  setup_all do
    Endpoint.start_link
    :ok
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

  defp check_origin(origin, origins) do
    conn = conn(:get, "/") |> put_req_header("origin", origin)
    Transport.check_origin(conn, Endpoint, origins)
  end

  test "does not check origin if disabled" do
    refute check_origin("/", false).halted
  end

  test "checks origin against host" do
    refute check_origin("https://host.com/", true).halted
    conn = check_origin("https://another.com/", true)
    assert conn.halted
    assert conn.status == 403
  end

  test "checks the origin of requests against allowed origins" do
    origins = ["//example.com", "http://scheme.com", "//port.com:81"]

    refute check_origin("https://example.com/", origins).halted
    refute check_origin("http://port.com:81/", origins).halted

    conn = check_origin("http://notallowed.com/", origins)
    assert conn.halted
    assert conn.status == 403

    conn = check_origin("https://scheme.com/", origins)
    assert conn.halted
    assert conn.status == 403

    conn = check_origin("http://port.com:82/", origins)
    assert conn.halted
    assert conn.status == 403
  end

  ## force_ssl

  test "forces SSL" do
    # Halts
    conn = Transport.force_ssl(conn(:get, "http://foo.com/"), :socket, Endpoint)
    assert conn.halted
    assert get_resp_header(conn, "location") == ["https://host.com/"]

    # No-op when already halted
    conn = Transport.force_ssl(conn(:get, "http://foo.com/") |> halt(), :socket, Endpoint)
    assert conn.halted
    assert get_resp_header(conn, "location") == []

    # Valid
    conn = Transport.force_ssl(conn(:get, "https://foo.com/"), :socket, Endpoint)
    refute conn.halted
  end
end
