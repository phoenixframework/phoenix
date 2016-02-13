defmodule Phoenix.Endpoint.AdapterTest do
  use ExUnit.Case, async: true
  alias Phoenix.Endpoint.Adapter

  setup do
    Application.put_env(:phoenix, AdapterApp.Endpoint, custom: true)
    for {env_var, value} <- [{"PHOENIX_PORT", "8080"}, {"URL_SCHEME", "https"}, {"URL_PORT", "80"}, {"URL_HOST", "example.com"}, {"STATIC_HOST", "static.example.com"}] do
      System.put_env(env_var, value)
    end
    :ok
  end

  test "loads router configuration" do
    config = Adapter.config(:phoenix, AdapterApp.Endpoint)
    assert config[:otp_app] == :phoenix
    assert config[:custom] == true
    assert config[:render_errors] == [view: AdapterApp.ErrorView, accepts: ~w(html), layout: false]
  end

  defmodule HTTPSEndpoint do
    def path(path), do: path
    def config(:http), do: false
    def config(:https), do: [port: 443]
    def config(:url), do: [host: "example.com"]
    def config(:otp_app), do: :phoenix
  end

  defmodule HTTPEndpoint do
    def path(path), do: path
    def config(:https), do: false
    def config(:http), do: [port: 80]
    def config(:url), do: [host: "example.com"]
    def config(:otp_app), do: :phoenix
  end

  defmodule HTTPEnvVarEndpoint do
    def config(:https), do: false
    def config(:http), do: [port: {:system,"PHOENIX_PORT"}]
    def config(:url), do: [host: "example.com"]
    def config(:otp_app), do: :phoenix
  end

  defmodule URLEnvVarEndpoint do
    def config(:https), do: false
    def config(:http), do: false
    def config(:url), do: [host: {:system, "URL_HOST"},
                           port: {:system, "URL_PORT"},
                           scheme: {:system, "URL_SCHEME"}]
    def config(:static_url), do: nil
  end

  defmodule URLEndpoint do
    def config(:https), do: false
    def config(:http), do: false
    def config(:url), do: [host: "example.com", port: 678, scheme: "random"]
    def config(:static_url), do: nil
  end

  defmodule StaticURLEndpoint do
    def config(:https), do: false
    def config(:http), do: false
    def config(:static_url), do: [host: "static.example.com"]
  end

  defmodule StaticURLEnvVarEndpoint do
    def config(:https), do: false
    def config(:http), do: false
    def config(:static_url), do: [host: {:system, "STATIC_HOST"}]
  end

  test "generates the static url based on the static host configuration" do
    static_host = {:cache, "http://static.example.com"}
    assert Adapter.static_url(StaticURLEndpoint) == static_host
  end

  test "generates the static url based on env variables" do
    static_host = {:cache, "http://static.example.com"}
    assert Adapter.static_url(StaticURLEnvVarEndpoint) == static_host
  end

  test "static url fallbacks to url when there is no configuration for static_url" do
    assert Adapter.static_url(URLEndpoint) == {:cache, "random://example.com:678"}
  end

  test "generates url" do
    assert Adapter.url(URLEndpoint) == {:cache, "random://example.com:678"}
    assert Adapter.url(HTTPEndpoint) == {:cache, "http://example.com"}
    assert Adapter.url(HTTPSEndpoint) == {:cache, "https://example.com"}
    assert Adapter.url(HTTPEnvVarEndpoint) == {:cache, "http://example.com:8080"}
    assert Adapter.url(URLEnvVarEndpoint) == {:cache, "https://example.com:80"}
  end

  test "static_path/2 returns file's path with lookup cache" do
    assert {:nocache, "/phoenix.png"} =
             Adapter.static_path(HTTPEndpoint, "/phoenix.png")
    assert {:nocache, "/images/unknown.png"} =
             Adapter.static_path(HTTPEndpoint, "/images/unknown.png")
  end
end
