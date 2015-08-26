defmodule Phoenix.Endpoint.EndpointTest do
  use ExUnit.Case, async: true
  use RouterHelper

  @config [url: [host: "example.com", path: "/api"],
           static_url: [host: "static.example.com"],
           server: false, http: [port: 80], https: [port: 443],
           force_ssl: [subdomains: true],
           cache_static_lookup: true, cache_static_manifest: "../../../../test/fixtures/manifest.json",
           pubsub: [adapter: Phoenix.PubSub.PG2, name: :endpoint_pub]]
  Application.put_env(:phoenix, __MODULE__.Endpoint, @config)

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix

    # Assert endpoint variables
    assert is_list(config)
    assert otp_app == :phoenix
    assert code_reloading? == false
  end

  setup_all do
    Endpoint.start_link()
    :ok
  end

  test "has reloadable configuration" do
    assert Endpoint.config(:url) == [host: "example.com", path: "/api"]
    assert Endpoint.config(:static_url) == [host: "static.example.com"]
    assert Endpoint.url == "https://example.com"
    assert Endpoint.static_url == "https://static.example.com"
    assert Endpoint.struct_url == %URI{scheme: "https", host: "example.com", port: 443}

    config = put_in(@config[:url][:port], 1234)
    |> put_in([:static_url, :port], 456)

    assert Endpoint.config_change([{Endpoint, config}], []) == :ok
    assert Endpoint.config(:url) == [host: "example.com", path: "/api", port: 1234]
    assert Endpoint.config(:static_url) == [port: 456, host: "static.example.com"]
    assert Endpoint.url == "https://example.com:1234"
    assert Endpoint.static_url == "https://static.example.com:456"
    assert Endpoint.struct_url == %URI{scheme: "https", host: "example.com", port: 1234}
  end

  test "sets script name when using path" do
    assert Endpoint.call(conn(:get, "/"), []).script_name == ~w"api"
  end

  test "redirects http requests to https on force_ssl" do
    conn = Endpoint.call(conn(:get, "/"), [])
    assert get_resp_header(conn, "location") == ["https://example.com/"]
    assert conn.halted
  end

  test "sends hsts on https requests on force_ssl" do
    conn = Endpoint.call(conn(:get, "https://example.com/"), [])
    assert get_resp_header(conn, "strict-transport-security") ==
           ["max-age=31536000; includeSubDomains"]
  end

  test "reads static path with and without caching" do
    file = Path.expand("priv/static/phoenix.png", File.cwd!)

    # Old timestamp
    old_stat = File.stat!(file)
    old_vsn  = static_vsn(old_stat)
    assert Endpoint.static_path("/phoenix.png") == "/phoenix.png?vsn=#{old_vsn}"

    # Now with cache disabled
    config = put_in(@config[:cache_static_lookup], false)
    assert Endpoint.config_change([{Endpoint, config}], []) == :ok

    # New timestamp
    File.touch!(file)
    new_stat = File.stat!(file)
    new_vsn  = static_vsn(new_stat)
    assert Endpoint.static_path("/phoenix.png") == "/phoenix.png?vsn=#{new_vsn}"

    # Now with cache enabled
    config = put_in(@config[:cache_static_lookup], true)
    assert Endpoint.config_change([{Endpoint, config}], []) == :ok

    assert Endpoint.static_path("/phoenix.png") == "/phoenix.png?vsn=#{new_vsn}"
    File.touch!(file, old_stat.mtime)
    assert Endpoint.static_path("/phoenix.png") == "/phoenix.png?vsn=#{new_vsn}"
  end

  test "warms up caches on load and config change" do
    assert Endpoint.static_path("/foo.css") == "/foo-abcdef.css?vsn=d"

    # Trigger a config change and the cache should be warmed up again
    assert Endpoint.config_change([{Endpoint, @config}], []) == :ok

    assert Endpoint.static_path("/foo.css") == "/foo-abcdef.css?vsn=d"
  end

  test "uses url configuration for static path" do
    Application.put_env(:phoenix, __MODULE__.UrlEndpoint, url: [path: "/api"])
    defmodule UrlEndpoint do
      use Phoenix.Endpoint, otp_app: :phoenix
    end
    UrlEndpoint.start_link
    assert UrlEndpoint.static_path("/phoenix.png") =~ "/api/phoenix.png?vsn="
  end

  test "uses static_url configuration for static path" do
    Application.put_env(:phoenix, __MODULE__.StaticEndpoint, static_url: [path: "/static"])
    defmodule StaticEndpoint do
      use Phoenix.Endpoint, otp_app: :phoenix
    end
    StaticEndpoint.start_link
    assert StaticEndpoint.static_path("/phoenix.png") =~ "/static/phoenix.png?vsn="
  end

  test "injects pubsub broadcast with configured server" do
    Endpoint.subscribe(self, "sometopic")
    some = spawn fn -> end

    Endpoint.broadcast_from(some, "sometopic", "event1", %{key: :val})
    assert_receive %Phoenix.Socket.Broadcast{
      event: "event1", payload: %{key: :val}, topic: "sometopic"}

    Endpoint.broadcast_from!(some, "sometopic", "event2", %{key: :val})
    assert_receive %Phoenix.Socket.Broadcast{
      event: "event2", payload: %{key: :val}, topic: "sometopic"}

    Endpoint.broadcast("sometopic", "event3", %{key: :val})
    assert_receive %Phoenix.Socket.Broadcast{
      event: "event3", payload: %{key: :val}, topic: "sometopic"}

    Endpoint.broadcast!("sometopic", "event4", %{key: :val})
    assert_receive %Phoenix.Socket.Broadcast{
      event: "event4", payload: %{key: :val}, topic: "sometopic"}
  end

  defp static_vsn(file) do
    {file.size, file.mtime} |> :erlang.phash2() |> Integer.to_string(16)
  end
end
