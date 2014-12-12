defmodule Phoenix.EndpointTest do
  use ExUnit.Case, async: true
  use RouterHelper

  @config [url: [host: "example.com"]]
  Application.put_env(:endpoint_app, __MODULE__.Endpoint, @config)

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :endpoint_app

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

    config = put_in @config[:url][:port], 1234
    assert Endpoint.config_change([{Endpoint, config}], []) == :ok
    assert Endpoint.config(:url) == [host: "example.com", port: 1234]
    assert Endpoint.url("/") == "http://example.com:1234/"
  end

  test "does not include code reloading if disabled" do
    assert is_map Endpoint.call(conn(:get, "/"), [])
  end
end