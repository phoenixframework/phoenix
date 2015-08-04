defmodule Phoenix.Channel.TransportTest do
  use ExUnit.Case, async: true
  use RouterHelper

  alias Phoenix.Channel.Transport

  def config(:url) do
    [host: "host.com"]
  end

  defp check_origin(origin, origins) do
    conn = conn(:get, "/") |> put_req_header("origin", origin)
    Transport.check_origin(conn, __MODULE__, origins)
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
end
