defmodule Phoenix.Endpoint.SupervisorTest do
  use ExUnit.Case, async: true
  alias Phoenix.Endpoint.Supervisor

  setup do
    Application.put_env(:phoenix, SupervisorApp.Endpoint, custom: true)
    System.put_env("PHOENIX_PORT", "8080")
    System.put_env("PHOENIX_HOST", "example.org")
    :ok
  end

  test "loads router configuration" do
    config = Supervisor.config(:phoenix, SupervisorApp.Endpoint)
    assert config[:otp_app] == :phoenix
    assert config[:custom] == true

    assert config[:render_errors] ==
             [view: SupervisorApp.ErrorView, accepts: ~w(html), layout: false]
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
    def config(:http), do: [port: {:system, "PHOENIX_PORT"}]
    def config(:url), do: [host: {:system, "PHOENIX_HOST"}]
    def config(:otp_app), do: :phoenix
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

  defmodule WatchersEndpoint do
    def init(:supervisor, config), do: {:ok, config}
    def __sockets__(), do: []
  end

  test "generates the static url based on the static host configuration" do
    static_host = {:cache, "http://static.example.com"}
    assert Supervisor.static_url(StaticURLEndpoint) == static_host
  end

  test "static url fallbacks to url when there is no configuration for static_url" do
    assert Supervisor.static_url(URLEndpoint) == {:cache, "random://example.com:678"}
  end

  test "generates url" do
    assert Supervisor.url(URLEndpoint) == {:cache, "random://example.com:678"}
    assert Supervisor.url(HTTPEndpoint) == {:cache, "http://example.com"}
    assert Supervisor.url(HTTPSEndpoint) == {:cache, "https://example.com"}
    assert Supervisor.url(HTTPEnvVarEndpoint) == {:cache, "http://example.org:8080"}
  end

  test "static_path/2 returns file's path with lookup cache" do
    assert {:nocache, {"/phoenix.png", nil}} =
             Supervisor.static_lookup(HTTPEndpoint, "/phoenix.png")

    assert {:nocache, {"/images/unknown.png", nil}} =
             Supervisor.static_lookup(HTTPEndpoint, "/images/unknown.png")
  end

  describe "watchers" do
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

  defmodule TestEndpoint do
    use Phoenix.Endpoint, otp_app: :phoenix
  end

  defmodule TestEndpoint1 do
    use Phoenix.Endpoint, otp_app: :phoenix
  end

  defmodule TestEndpoint2 do
    use Phoenix.Endpoint, otp_app: :phoenix
  end

  # This is just here to silence the warnings about no config for TestEndpoint:
  Application.put_env(:phoenix, __MODULE__.TestEndpoint, server: false)
  Application.put_env(:phoenix, __MODULE__.TestEndpoint1, server: false)
  Application.put_env(:phoenix, __MODULE__.TestEndpoint2, server: false)

  describe "optional name config for Endpoint and EndpointConfig" do
    test "can start multiple Endpoint supervisors if they have different names - endpoint name is an atom" do
      {:ok, endpoint1_pid} =
        Phoenix.Endpoint.Supervisor.start_link(:phoenix, TestEndpoint,
          strategy: :one_for_one,
          name: :endpoint1
        )

      assert Process.alive?(endpoint1_pid)
      assert Process.whereis(:endpoint1) == endpoint1_pid
      assert Process.whereis(:endpoint1_config) |> Process.alive?()

      {:ok, endpoint2_pid} =
        Phoenix.Endpoint.Supervisor.start_link(:phoenix, TestEndpoint,
          strategy: :one_for_one,
          name: :endpoint2
        )

      assert Process.alive?(endpoint2_pid)
      assert Process.whereis(:endpoint2) == endpoint2_pid
      assert Process.whereis(:endpoint2_config) |> Process.alive?()
    end

    test "can start multiple Endpoint supervisors if they have different names - endpoint name is a Module" do
      {:ok, endpoint1_pid} =
        Phoenix.Endpoint.Supervisor.start_link(:phoenix, TestEndpoint1, strategy: :one_for_one)

      assert Process.alive?(endpoint1_pid)
      assert Process.whereis(TestEndpoint1) == endpoint1_pid
      assert Process.whereis(TestEndpoint1.Config) |> Process.alive?()

      {:ok, endpoint2_pid} =
        Phoenix.Endpoint.Supervisor.start_link(:phoenix, TestEndpoint2,
          strategy: :one_for_one,
          name: TestEndpoint2
        )

      assert Process.alive?(endpoint2_pid)
      assert Process.whereis(TestEndpoint2) == endpoint2_pid
      assert Process.whereis(TestEndpoint2.Config) |> Process.alive?()
    end

    test "cannot start multiple Endpoint supervisors if they have the same name (default behavior)" do
      {:ok, endpoint1_pid} = Phoenix.Endpoint.Supervisor.start_link(:phoenix, TestEndpoint)
      assert Process.alive?(endpoint1_pid)

      {:error, {:already_started, pid}} =
        Phoenix.Endpoint.Supervisor.start_link(:phoenix, TestEndpoint)

      assert pid == endpoint1_pid
    end
  end
end
