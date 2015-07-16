# TODO: We need simpler unit tests that
# do pass through the whole endpoint
defmodule Phoenix.Channel.TransportTest do
  use ExUnit.Case, async: true
  use RouterHelper

  alias __MODULE__.Endpoint

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :transport_app
    plug :check_origin
    plug :render
    defp check_origin(conn, _) do
      allowed_origins = ["//example.com", "http://scheme.com", "//port.com:81"]
      Phoenix.Channel.Transport.check_origin(conn, allowed_origins)
    end
    defp render(conn, _),
      do: send_resp(conn, 200, "ok")
  end

  setup_all do
    Endpoint.start_link()
    :ok
  end

  defp call(origin) do
    conn(:get, "/")
    |> put_req_header("origin", origin)
    |> Endpoint.call([])
  end

  test "does not check origin if none is given" do
    conn = conn(:get, "/") |> Endpoint.call([])
    assert conn.status == 200
  end

  test "check the origin of requests against allowed origins" do
    assert call("https://example.com").status == 200
    assert call("http://port.com:81").status == 200
    assert call("http://notallowed.com").status == 403
    assert call("https://scheme.com").status == 403
    assert call("http://port.com:82").status == 403
  end
end
