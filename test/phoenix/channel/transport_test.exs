defmodule Phoenix.Channel.TransportTest do
  use ExUnit.Case, async: true
  use RouterHelper

  alias __MODULE__.Endpoint

  Application.put_env(:transport_app, Endpoint, [
    transports: [
      origins: ["//example.com", "http://scheme.com", "//port.com:81"]]
  ])

  defmodule Router do
    use Plug.Router
    plug :check_origin
    plug :match
    plug :dispatch

    defp check_origin(conn, _),
      do: Phoenix.Channel.Transport.check_origin(conn)
    get "/",
      do: send_resp(conn, :ok, "")
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :transport_app
    plug Router
  end

  setup_all do
    Endpoint.start_link
    :ok
  end

  test "check the origin of requests against allowed origins" do
    conn = call(Endpoint, :get, "/", [], headers: [])
    assert conn.status == 200
    conn = call(Endpoint, :get, "/", [], headers: [{"origin", "https://example.com"}])
    assert conn.status == 200
    conn = call(Endpoint, :get, "/", [], headers: [{"origin", "http://port.com:81"}])
    assert conn.status == 200

    conn = call(Endpoint, :get, "/", [], headers: [{"origin", "http://notallowed.com"}])
    assert conn.status == 403
    conn = call(Endpoint, :get, "/", [], headers: [{"origin", "https://scheme.com"}])
    assert conn.status == 403
    conn = call(Endpoint, :get, "/", [], headers: [{"origin", "http://port.com:82"}])
    assert conn.status == 403
  end
end
