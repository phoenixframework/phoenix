defmodule Phoenix.Endpoint.AdapterTest do
  use ExUnit.Case, async: true
  alias Phoenix.Endpoint.Adapter

  setup do
    config = [custom: true]
    Application.put_env(:phoenix, AdapterApp.Endpoint, config)
    :ok
    System.put_env("PHOENIX_PORT", "8080")
  end

  test "loads router configuration" do
    config = Adapter.config(:phoenix, AdapterApp.Endpoint)
    assert config[:otp_app] == :phoenix
    assert config[:custom] == true
    assert config[:render_errors] == [view: AdapterApp.ErrorView, format: "html"]
  end

  defmodule HTTPSEndpoint do
    def config(:https), do: [port: 443]
    def config(:url), do: [host: "example.com"]
    def config(:otp_app), do: :phoenix
    def config(:cache_static_lookup), do: false
  end

  defmodule HTTPEndpoint do
    def config(:https), do: false
    def config(:http), do: [port: 80]
    def config(:url), do: [host: "example.com"]
    def config(:otp_app), do: :phoenix
    def config(:cache_static_lookup), do: true
  end

  defmodule HTTPEnvVarEndpoint do
    def config(:https), do: false
    def config(:http), do: [port: {:system,"PHOENIX_PORT"}]
    def config(:url), do: [host: "example.com"]
    def config(:otp_app), do: :phoenix
    def config(:cache_static_lookup), do: true
  end

  defmodule URLEndpoint do
    def config(:https), do: false
    def config(:http), do: false
    def config(:url), do: [host: "example.com", port: 678, scheme: "random"]
  end

  test "generates url" do
    assert Adapter.url(URLEndpoint) == {:cache, "random://example.com:678"}
    assert Adapter.url(HTTPEndpoint) == {:cache, "http://example.com"}
    assert Adapter.url(HTTPSEndpoint) == {:cache, "https://example.com"}
    assert Adapter.url(HTTPEnvVarEndpoint) == {:cache, "http://example.com:8080"}
  end

  test "static_path/2 returns file's path with lookup cache" do
    assert {:cache, "/images/phoenix.png?" <> _} =
             Adapter.static_path(HTTPEndpoint, "/images/phoenix.png")
    assert {:stale, "/images/unknown.png"} =
             Adapter.static_path(HTTPEndpoint, "/images/unknown.png")
  end

  test "static_path/2 returns file's path without lookup cache" do
    assert {:stale, "/images/phoenix.png?" <> _} =
             Adapter.static_path(HTTPSEndpoint, "/images/phoenix.png")
    assert {:stale, "/images/unknown.png"} =
             Adapter.static_path(HTTPSEndpoint, "/images/unknown.png")
  end
end
