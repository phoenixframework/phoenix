System.put_env("ENDPOINT_TEST_HOST", "example.com")

defmodule Phoenix.Endpoint.EndpointTest do
  use ExUnit.Case, async: true
  use RouterHelper

  @config [url: [host: {:system, "ENDPOINT_TEST_HOST"}, path: "/api"],
           static_url: [host: "static.example.com"],
           server: false, http: [port: 80], https: [port: 443],
           force_ssl: [subdomains: true],
           cache_static_manifest: "../../../../test/fixtures/digest/compile/cache_manifest.json",
           pubsub_server: :endpoint_pub]

  Application.put_env(:phoenix, __MODULE__.Endpoint, @config)

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix

    # Assert endpoint variables
    assert is_list(config)
    assert @otp_app == :phoenix
    assert code_reloading? == false
    assert @compile_config == [force_ssl: [subdomains: true]]
  end

  defmodule NoConfigEndpoint do
    use Phoenix.Endpoint, otp_app: :phoenix
  end

  setup_all do
    ExUnit.CaptureLog.capture_log(fn -> start_supervised! Endpoint end)
    start_supervised! {Phoenix.PubSub, name: :endpoint_pub}
    on_exit fn -> Application.delete_env(:phoenix, :serve_endpoints) end
    :ok
  end

  test "defines child_spec/1" do
    assert Endpoint.child_spec([]) == %{
      id: Endpoint,
      start: {Endpoint, :start_link, [[]]},
      type: :supervisor
    }
  end

  test "warns if there is no configuration for an endpoint" do
    assert ExUnit.CaptureLog.capture_log(fn ->
      NoConfigEndpoint.start_link()
    end) =~ "no configuration"
  end

  test "has reloadable configuration" do
    endpoint_id = Endpoint.config(:endpoint_id)
    assert Endpoint.config(:url) == [host: {:system, "ENDPOINT_TEST_HOST"}, path: "/api"]
    assert Endpoint.config(:static_url) == [host: "static.example.com"]
    assert Endpoint.url() == "https://example.com"
    assert Endpoint.path("/") == "/api/"
    assert Endpoint.static_url() == "https://static.example.com"
    assert Endpoint.struct_url() == %URI{scheme: "https", host: "example.com", port: 443}

    config =
      @config
      |> put_in([:url, :port], 1234)
      |> put_in([:static_url, :port], 456)

    assert Endpoint.config_change([{Endpoint, config}], []) == :ok
    assert Endpoint.config(:endpoint_id) == endpoint_id
    assert Enum.sort(Endpoint.config(:url)) ==
           [host: {:system, "ENDPOINT_TEST_HOST"}, path: "/api", port: 1234]
    assert Enum.sort(Endpoint.config(:static_url)) ==
           [host: "static.example.com", port: 456]
    assert Endpoint.url() == "https://example.com:1234"
    assert Endpoint.path("/") == "/api/"
    assert Endpoint.static_url() == "https://static.example.com:456"
    assert Endpoint.struct_url() == %URI{scheme: "https", host: "example.com", port: 1234}
  end

  test "sets script name when using path" do
    conn = conn(:get, "https://example.com/")
    assert Endpoint.call(conn, []).script_name == ~w"api"

    conn = put_in conn.script_name, ~w(foo)
    assert Endpoint.call(conn, []).script_name == ~w"api"
  end

  @tag :capture_log
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

  test "warms up caches on load and config change" do
    assert Endpoint.config(:cache_static_manifest_latest) ==
             %{"foo.css" => "foo-d978852bea6530fcd197b5445ed008fd.css"}

    assert Endpoint.static_path("/foo.css") == "/foo-d978852bea6530fcd197b5445ed008fd.css?vsn=d"

    # Trigger a config change and the cache should be warmed up again
    config = put_in(@config[:cache_static_manifest], "../../../../test/fixtures/digest/compile/cache_manifest_upgrade.json")

    assert Endpoint.config_change([{Endpoint, config}], []) == :ok
    assert Endpoint.config(:cache_static_manifest_latest) == %{"foo.css" => "foo-ghijkl.css"}
    assert Endpoint.static_path("/foo.css") == "/foo-ghijkl.css?vsn=d"
  end

  @tag :capture_log
  test "invokes init/2 callback" do
    defmodule InitEndpoint do
      use Phoenix.Endpoint, otp_app: :phoenix

      def init(:supervisor, opts) do
        send opts[:parent], {self(), :sample}
        {:ok, opts}
      end
    end

    {:ok, pid} = InitEndpoint.start_link(parent: self())
    assert_receive {^pid, :sample}
  end

  @tag :capture_log
  test "uses url configuration for static path" do
    Application.put_env(:phoenix, __MODULE__.UrlEndpoint, url: [path: "/api"])
    defmodule UrlEndpoint do
      use Phoenix.Endpoint, otp_app: :phoenix
    end
    UrlEndpoint.start_link()
    assert UrlEndpoint.path("/phoenix.png") =~ "/api/phoenix.png"
    assert UrlEndpoint.static_path("/phoenix.png") =~ "/api/phoenix.png"
  end

  @tag :capture_log
  test "uses static_url configuration for static path" do
    Application.put_env(:phoenix, __MODULE__.StaticEndpoint, static_url: [path: "/static"])
    defmodule StaticEndpoint do
      use Phoenix.Endpoint, otp_app: :phoenix
    end
    StaticEndpoint.start_link()
    assert StaticEndpoint.path("/phoenix.png") =~ "/phoenix.png"
    assert StaticEndpoint.static_path("/phoenix.png") =~ "/static/phoenix.png"
  end

  test "injects pubsub broadcast with configured server" do
    Endpoint.subscribe("sometopic")
    some = spawn fn -> :ok end

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

    Endpoint.local_broadcast_from(some, "sometopic", "event1", %{key: :val})
    assert_receive %Phoenix.Socket.Broadcast{
      event: "event1", payload: %{key: :val}, topic: "sometopic"}

    Endpoint.local_broadcast("sometopic", "event3", %{key: :val})
    assert_receive %Phoenix.Socket.Broadcast{
      event: "event3", payload: %{key: :val}, topic: "sometopic"}
  end

  test "loads cache manifest from specified application" do
    config = put_in(@config[:cache_static_manifest], {:phoenix, "../../../../test/fixtures/digest/compile/cache_manifest.json"})
    
    assert Endpoint.config_change([{Endpoint, config}], []) == :ok
    assert Endpoint.static_path("/foo.css") == "/foo-d978852bea6530fcd197b5445ed008fd.css?vsn=d"
  end

  test "server?/2 returns true for explicitly true server", config do
    endpoint = Module.concat(__MODULE__, config.test)
    Application.put_env(:phoenix, endpoint, server: true)
    assert Phoenix.Endpoint.server?(:phoenix, endpoint)
  end

  test "server?/2 returns false for explicitly false server", config do
    Application.put_env(:phoenix, :serve_endpoints, true)
    endpoint = Module.concat(__MODULE__, config.test)
    Application.put_env(:phoenix, endpoint, server: false)
    refute Phoenix.Endpoint.server?(:phoenix, endpoint)
  end

  test "server?/2 returns true for global serve_endpoints as true", config do
    Application.put_env(:phoenix, :serve_endpoints, true)
    endpoint = Module.concat(__MODULE__, config.test)
    Application.put_env(:phoenix, endpoint, [])
    assert Phoenix.Endpoint.server?(:phoenix, endpoint)
  end

  test "server?/2 returns false for no global serve_endpoints config", config do
    Application.delete_env(:phoenix, :serve_endpoints)
    endpoint = Module.concat(__MODULE__, config.test)
    Application.put_env(:phoenix, endpoint, [])
    refute Phoenix.Endpoint.server?(:phoenix, endpoint)
  end

  test "static_path/1 validates paths are local/safe" do
    safe_path = "/some_safe_path"
    assert Endpoint.static_path(safe_path) == safe_path

    assert_raise ArgumentError, ~r/unsafe characters/, fn ->
      Endpoint.static_path("/\\unsafe_path")
    end

    assert_raise ArgumentError, ~r/expected a path starting with a single/, fn ->
      Endpoint.static_path("//invalid_path")
    end
  end

  test "static_integrity/1 validates paths are local/safe" do
    safe_path = "/some_safe_path"
    assert is_nil(Endpoint.static_integrity(safe_path))

    assert_raise ArgumentError, ~r/unsafe characters/, fn ->
      Endpoint.static_integrity("/\\unsafe_path")
    end

    assert_raise ArgumentError, ~r/expected a path starting with a single/, fn ->
      Endpoint.static_integrity("//invalid_path")
    end
  end

  test "__compile_config__/0 returns selected configs from compile time" do
    assert Endpoint.__compile_config__() == [force_ssl: [subdomains: true]]
  end
end
