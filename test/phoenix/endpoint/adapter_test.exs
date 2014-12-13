defmodule Phoenix.Endpoint.AdapterTest do
  use ExUnit.Case, async: true
  alias Phoenix.Endpoint.Adapter

  setup do
    config = [custom: true]
    Application.put_env(:phoenix, AdapterApp.Endpoint, config)
    :ok
  end

  test "loads router configuration" do
    config = Adapter.config(:phoenix, AdapterApp.Endpoint)
    assert config[:otp_app] == :phoenix
    assert config[:custom] == true
    assert config[:render_errors] == AdapterApp.ErrorView
  end

  defmodule HTTPSEndpoint do
    def config(:https), do: [port: 443]
    def config(:url), do: [host: "example.com"]
  end

  defmodule HTTPEndpoint do
    def config(:https), do: false
    def config(:http), do: [port: 80]
    def config(:url), do: [host: "example.com"]
    def config(:otp_app), do: :phoenix
    def config(:static), do: [root: "../../../../test/fixtures/static/", route: "/"]
  end

  defmodule URLEndpoint do
    def config(:https), do: false
    def config(:http), do: false
    def config(:url), do: [host: "example.com", port: 678, scheme: "random"]
  end

  test "generates url" do
    assert Adapter.url(URLEndpoint) == "random://example.com:678"
    assert Adapter.url(HTTPEndpoint) == "http://example.com"
    assert Adapter.url(HTTPSEndpoint) == "https://example.com"
  end

  test "static_path/2 returns file's path with timestamp when file exists" do
    assert Adapter.static_path(HTTPEndpoint, "/images/phoenix.png") =~ ~r"/images/phoenix\.png\?\d+"
    assert Adapter.static_path(HTTPEndpoint, "/images/unknown.png") =~ ~r"/images/unknown\.png"
  end

  test "static_path/2 returns file's path with no timestamp when file doesn't exist" do
    assert Adapter.static_path(HTTPEndpoint, "/images/logo.png") == "/images/logo.png"
  end
end
