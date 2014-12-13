defmodule Phoenix.EndpointTest do
  use ExUnit.Case, async: true
  use RouterHelper

  @config [url: [host: "example.com"],
           static: [root: "/priv/static", route: "/"]]
  Application.put_env(:phoenix, __MODULE__.Endpoint, @config)

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix

    plug Phoenix.CodeReloader, reloader: &__MODULE__.reload!/0

    def reload! do
      flunk "reloading should have been disabled"
    end
  end

  setup do
    Endpoint.start_link()
    :ok
  end

  test "has reloadable configuration" do
    assert Endpoint.config(:url) == [host: "example.com"]
    assert Endpoint.url("/") == "http://example.com/"
    assert Endpoint.static_path("images/foo.png") == "/images/foo.png"

    config = put_in(@config[:url][:port], 1234)
    config = put_in(config[:static][:route], "/static")
    assert Endpoint.config_change([{Endpoint, config}], []) == :ok
    assert Endpoint.config(:url) == [host: "example.com", port: 1234]
    assert Endpoint.url("/") == "http://example.com:1234/"
    assert Endpoint.static_path("/images/foo.png") == "/static/images/foo.png"
  end

  test "does not include code reloading if disabled" do
    assert is_map Endpoint.call(conn(:get, "/"), [])
  end
end