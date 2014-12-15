defmodule Phoenix.EndpointTest do
  use ExUnit.Case, async: true
  use RouterHelper

  @config [url: [host: "example.com"]]
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

    config = put_in(@config[:url][:port], 1234)
    assert Endpoint.config_change([{Endpoint, config}], []) == :ok
    assert Endpoint.config(:url) == [host: "example.com", port: 1234]
    assert Endpoint.url("/") == "http://example.com:1234/"
  end

  test "static_path/1 with and without caching" do
    file = Path.expand("priv/static/images/phoenix.png", File.cwd!)

    # Old timestamp
    old_mtime   = File.stat!(file).mtime
    old_seconds = :calendar.datetime_to_gregorian_seconds(old_mtime)
    assert Endpoint.static_path("/images/phoenix.png") == "/images/phoenix.png?#{old_seconds}"

    # New timestamp
    File.touch!(file)
    new_mtime   = File.stat!(file).mtime
    new_seconds = :calendar.datetime_to_gregorian_seconds(new_mtime)
    assert Endpoint.static_path("/images/phoenix.png") == "/images/phoenix.png?#{new_seconds}"

    # Now with cache enabled
    config = put_in(@config[:cache_static_lookup], true)
    assert Endpoint.config_change([{Endpoint, config}], []) == :ok

    assert Endpoint.static_path("/images/phoenix.png") == "/images/phoenix.png?#{new_seconds}"
    File.touch!(file, old_mtime)
    assert Endpoint.static_path("/images/phoenix.png") == "/images/phoenix.png?#{new_seconds}"
  end

  test "does not include code reloading if disabled" do
    assert is_map Endpoint.call(conn(:get, "/"), [])
  end
end
