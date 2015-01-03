defmodule Mix.PhoenixTest do
  use ExUnit.Case, async: true

  test "base/0 returns the module base based on the Mix application" do
    assert Mix.Phoenix.base == "Phoenix"
    Application.put_env(:phoenix, :phoenix_namespace, Phoenix.Sample.App)
    assert Mix.Phoenix.base == "Phoenix.Sample.App"
  after
    Application.delete_env(:phoenix, :phoenix_namespace)
  end

  test "modules/0 returns all modules in project" do
    assert Phoenix.Router in Mix.Phoenix.modules
  end
end
