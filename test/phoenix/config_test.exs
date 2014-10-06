defmodule Phoenix.Config.ConfigTest do
  use ExUnit.Case, async: false
  alias Phoenix.Config

  setup_all do
    Mix.Config.persist(phoenix: [
      {Router,
         port: 1234,
         ssl: true
      },
      {:logger, [level: :info]}
    ])
  end

  test "router/2 returns the value for provided router module and get_in path" do
    assert Config.router(Router, [:port]) == 1234
  end

  test "router!/2 returns the value for provided router module and get_in path" do
    assert Config.router!(Router, [:port]) == 1234
  end

  test "router!/2 raises UndefinedConfigError when value is nil" do
    assert_raise Config.UndefinedConfigError, fn ->
      Config.router!(Router, [:key_that_does_not_exist])
    end
  end

  test "router/1 returns the keyword list configuration of module with merge defaults" do
    assert Enum.sort(Config.router(Router)) == Enum.sort([
      catch_errors: true,
      debug_errors: false,
      host: "localhost",
      error_controller: Phoenix.Controller.ErrorController,
      port: 1234,
      secret_key_base: nil,
      ssl: true
    ])
  end

  test "get/1 returns the config value for provided get_in path" do
    assert Config.get([:logger, :level]) == :info
  end

  test "get!/1 raises UndefinedConfigError if value is nil" do
    assert_raise Config.UndefinedConfigError, fn ->
      Config.get!([:logger, :key_that_does_not_exist])
    end
  end

  test "default/1 returns the default config value" do
    assert Config.default([:router, :port]) == 4000
  end

  test "default!/1 raises UndefinedConfigError if value is nil" do
    assert_raise Config.UndefinedConfigError, fn ->
      Config.default!([:logger, :key_that_does_not_exist])
    end
  end

end

