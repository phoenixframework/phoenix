defmodule Phoenix.Endpoint.SupervisorTest do
  use ExUnit.Case, async: true
  alias Phoenix.Endpoint.Supervisor

  defmodule HTTPSEndpoint do
    def config(:otp_app), do: :phoenix
    def config(:https), do: [port: 443]
    def config(:http), do: false
    def config(:url), do: [host: "example.com"]
    def config(:static_url), do: nil
  end

  defmodule HTTPEndpoint do
    def config(:otp_app), do: :phoenix
    def config(:https), do: false
    def config(:http), do: [port: 80]
    def config(:url), do: [host: "example.com"]
    def config(:static_url), do: nil
  end

  defmodule HTTPEnvVarEndpoint do
    def config(:otp_app), do: :phoenix
    def config(:https), do: false
    def config(:http), do: [port: {:system, "PHOENIX_PORT"}]
    def config(:url), do: [host: {:system, "PHOENIX_HOST"}]
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
    def config(:url), do: []
    def config(:static_url), do: [host: "static.example.com"]
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

  test "loads router configuration" do
    config = Supervisor.config(:phoenix, SupervisorApp.Endpoint)
    assert config[:otp_app] == :phoenix
    assert config[:custom] == true

    assert config[:render_errors] ==
             [view: SupervisorApp.ErrorView, accepts: ~w(html), layout: false]
  end

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

  describe "watchers" do
    defmodule WatchersEndpoint do
      def init(:supervisor, config), do: {:ok, config}
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
end
