defmodule Phoenix.Endpoint.Cowboy2AdapterTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  defmodule Endpoint do
    def config(:http3, _default), do: [ip: {127, 0, 0, 1}, port: 4443]
    def config(_key, default), do: default
    def init(opts), do: opts
    def call(conn, _opts), do: conn
  end

  test "builds HTTP/3 child spec with socket_opts and WebTransport defaults" do
    [spec] =
      Phoenix.Endpoint.Cowboy2Adapter.child_specs(Endpoint,
        otp_app: :phoenix,
        http3: [port: 4443, certfile: "cert.pem", keyfile: "key.pem"]
      )

    assert {Phoenix.Endpoint.Cowboy2Adapter, :start_http3,
            [Endpoint, _ref, transport_opts, proto_opts]} =
             spec.start

    assert %{socket_opts: socket_opts} = transport_opts
    assert socket_opts[:port] == 4443
    assert socket_opts[:certfile] == "cert.pem"
    assert socket_opts[:keyfile] == "key.pem"

    assert proto_opts.enable_connect_protocol == true
    assert proto_opts.h3_datagram == true
    assert proto_opts.enable_webtransport == true
    assert proto_opts.wt_max_sessions == 1
    assert is_map(proto_opts.env)
    assert proto_opts.env[:dispatch]
  end

  test "server_info/2 returns configured HTTP/3 address" do
    assert {:ok, {{127, 0, 0, 1}, 4443}} =
             Phoenix.Endpoint.Cowboy2Adapter.server_info(Endpoint, :http3)
  end

  test "logs explicit warning when http3 is configured with drainer" do
    log =
      capture_log(fn ->
        Phoenix.Endpoint.Cowboy2Adapter.child_specs(Endpoint,
          otp_app: :phoenix,
          http: [port: 4001],
          http3: [port: 4443, certfile: "cert.pem", keyfile: "key.pem"],
          drainer: []
        )
      end)

    assert log =~ "HTTP/3 WebTransport sessions are not drained by Plug.Cowboy.Drainer"
  end
end
