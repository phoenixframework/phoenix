defmodule Phoenix.Endpoint.SupervisorTest do
  use ExUnit.Case, async: false
  alias Phoenix.Endpoint.Supervisor

  defmodule HTTPSEndpoint do
    def config(:otp_app), do: :phoenix
    def config(:https), do: [port: 443]
    def config(:http), do: false
    def config(:url), do: [host: "example.com"]
    def config(_), do: nil
  end

  defmodule HTTPEndpoint do
    def config(:otp_app), do: :phoenix
    def config(:https), do: false
    def config(:http), do: [port: 80]
    def config(:url), do: [host: "example.com"]
    def config(_), do: nil
  end

  defmodule HTTPEnvVarEndpoint do
    def config(:otp_app), do: :phoenix
    def config(:https), do: false
    def config(:http), do: [port: {:system, "PHOENIX_PORT"}]
    def config(:url), do: [host: {:system, "PHOENIX_HOST"}]
    def config(_), do: nil
  end

  defmodule URLEndpoint do
    def config(:https), do: false
    def config(:http), do: false
    def config(:url), do: [host: "example.com", port: 678, scheme: "random"]
    def config(_), do: nil
  end

  defmodule StaticURLEndpoint do
    def config(:https), do: false
    def config(:http), do: []
    def config(:url), do: []
    def config(:static_url), do: [host: "static.example.com"]
    def config(_), do: nil
  end

  defmodule ServerEndpoint do
    def __sockets__(), do: []
  end

  setup_all do
    Application.put_env(:phoenix, SupervisorApp.Endpoint, custom: true)
    System.put_env("PHOENIX_PORT", "8080")
    System.put_env("PHOENIX_HOST", "example.org")

    [HTTPSEndpoint, HTTPEndpoint, HTTPEnvVarEndpoint, URLEndpoint, StaticURLEndpoint]
    |> Enum.each(&Supervisor.warmup/1)

    :ok
  end

  defp persistent!(endpoint), do: :persistent_term.get({Phoenix.Endpoint, endpoint})

  test "generates the static url based on the static host configuration" do
    assert persistent!(StaticURLEndpoint).static_url == "http://static.example.com"
  end

  test "static url fallbacks to url when there is no configuration for static_url" do
    assert persistent!(URLEndpoint).static_url == "random://example.com:678"
  end

  test "generates url" do
    assert persistent!(URLEndpoint).url == "random://example.com:678"
    assert persistent!(HTTPEndpoint).url == "http://example.com"
    assert persistent!(HTTPSEndpoint).url == "https://example.com"
    assert persistent!(HTTPEnvVarEndpoint).url == "http://example.org:8080"
  end

  test "static_path/2 returns file's path with lookup cache" do
    assert {:nocache, {"/phoenix.png", nil}} =
             Supervisor.static_lookup(HTTPEndpoint, "/phoenix.png")

    assert {:nocache, {"/images/unknown.png", nil}} =
             Supervisor.static_lookup(HTTPEndpoint, "/images/unknown.png")
  end

  import ExUnit.CaptureLog

  test "logs info if :http or :https configuration is set but not :server when running in release" do
    # simulate running inside release
    System.put_env("RELEASE_NAME", "phoenix-test")
    Application.put_env(:phoenix, ServerEndpoint, server: false, http: [], https: [])

    assert capture_log(fn ->
             {:ok, {_, _children}} = Supervisor.init({:phoenix, ServerEndpoint, []})
           end) =~ "Configuration :server"

    Application.put_env(:phoenix, ServerEndpoint, server: false, http: [])

    assert capture_log(fn ->
             {:ok, {_, _children}} = Supervisor.init({:phoenix, ServerEndpoint, []})
           end) =~ "Configuration :server"

    Application.put_env(:phoenix, ServerEndpoint, server: false, https: [])

    assert capture_log(fn ->
             {:ok, {_, _children}} = Supervisor.init({:phoenix, ServerEndpoint, []})
           end) =~ "Configuration :server"

    Application.put_env(:phoenix, ServerEndpoint, server: false)

    refute capture_log(fn ->
             {:ok, {_, _children}} = Supervisor.init({:phoenix, ServerEndpoint, []})
           end) =~ "Configuration :server"

    Application.put_env(:phoenix, ServerEndpoint, server: true)

    refute capture_log(fn ->
             {:ok, {_, _children}} = Supervisor.init({:phoenix, ServerEndpoint, []})
           end) =~ "Configuration :server"

    Application.delete_env(:phoenix, ServerEndpoint)
  end

  describe "watchers" do
    defmodule WatchersEndpoint do
      def __sockets__(), do: []
    end

    @watchers [esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]}]

    test "init/1 starts watcher children when `:server` config is true" do
      Application.put_env(:phoenix, WatchersEndpoint, server: true, watchers: @watchers)
      {:ok, {_, children}} = Supervisor.init({:phoenix, WatchersEndpoint, []})

      assert Enum.any?(children, fn
               %{start: {Phoenix.Endpoint.Watcher, :start_link, _config}} -> true
               _ -> false
             end)
    end

    test "init/1 doesn't start watchers when `:server` config is true and `:watchers` is false" do
      Application.put_env(:phoenix, WatchersEndpoint, server: true, watchers: false)
      {:ok, {_, children}} = Supervisor.init({:phoenix, WatchersEndpoint, []})

      refute Enum.any?(children, fn
               %{start: {Phoenix.Endpoint.Watcher, :start_link, _config}} -> true
               _ -> false
             end)
    end

    test "init/1 doesn't start watchers when `:server` config is false" do
      Application.put_env(:phoenix, WatchersEndpoint, server: false, watchers: @watchers)
      {:ok, {_, children}} = Supervisor.init({:phoenix, WatchersEndpoint, []})

      refute Enum.any?(children, fn
               %{start: {Phoenix.Endpoint.Watcher, :start_link, _config}} -> true
               _ -> false
             end)
    end

    test "init/1 starts watcher children when `:server` config is false and `:force_watchers` is true" do
      Application.put_env(:phoenix, WatchersEndpoint,
        server: false,
        force_watchers: true,
        watchers: @watchers
      )

      {:ok, {_, children}} = Supervisor.init({:phoenix, WatchersEndpoint, []})

      assert Enum.any?(children, fn
               %{start: {Phoenix.Endpoint.Watcher, :start_link, _config}} -> true
               _ -> false
             end)
    end
  end

  describe "origin & CSRF checks config" do
    defmodule TestSocket do
      @behaviour Phoenix.Socket.Transport
      def child_spec(_), do: :ignore
      def connect(_), do: {:ok, []}
      def init(state), do: {:ok, state}
      def handle_in(_, state), do: {:ok, state}
      def handle_info(_, state), do: {:ok, state}
      def terminate(_, _), do: :ok
    end

    defmodule SocketEndpoint do
      use Phoenix.Endpoint, otp_app: :phoenix

      socket "/ws", TestSocket, websocket: [check_csrf: false, check_origin: false]
    end

    Application.put_env(:phoenix, SocketEndpoint, [])

    test "fails when CSRF and origin checks both disabled in transport" do
      assert_raise ArgumentError, ~r/one of :check_origin and :check_csrf must be set/, fn ->
        Supervisor.init({:phoenix, SocketEndpoint, []})
      end
    end

    defmodule SocketEndpointOriginCheckDisabled do
      use Phoenix.Endpoint, otp_app: :phoenix

      socket "/ws", TestSocket, websocket: [check_csrf: false]
    end

    Application.put_env(:phoenix, SocketEndpointOriginCheckDisabled, check_origin: false)

    test "fails when origin is disabled in endpoint config and CSRF disabled in transport" do
      assert_raise ArgumentError, ~r/one of :check_origin and :check_csrf must be set/, fn ->
        Supervisor.init({:phoenix, SocketEndpointOriginCheckDisabled, []})
      end
    end
  end
end
