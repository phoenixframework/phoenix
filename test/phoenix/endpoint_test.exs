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
    old_stat = File.stat!(file)
    old_vsn  = static_vsn(old_stat)
    assert Endpoint.static_path("/images/phoenix.png") == "/images/phoenix.png?vsn=#{old_vsn}"

    # New timestamp
    File.touch!(file)
    new_stat = File.stat!(file)
    new_vsn  = static_vsn(new_stat)
    assert Endpoint.static_path("/images/phoenix.png") == "/images/phoenix.png?vsn=#{new_vsn}"

    # Now with cache enabled
    config = put_in(@config[:cache_static_lookup], true)
    assert Endpoint.config_change([{Endpoint, config}], []) == :ok

    assert Endpoint.static_path("/images/phoenix.png") == "/images/phoenix.png?vsn=#{new_vsn}"
    File.touch!(file, old_stat.mtime)
    assert Endpoint.static_path("/images/phoenix.png") == "/images/phoenix.png?vsn=#{new_vsn}"
  end

  test "does not include code reloading if disabled" do
    assert is_map Endpoint.call(conn(:get, "/"), [])
  end

  defp static_vsn(file) do
    {file.size, file.mtime} |> :erlang.phash2() |> Integer.to_string(16)
  end
end
