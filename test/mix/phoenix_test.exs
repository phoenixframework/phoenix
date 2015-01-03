defmodule Mix.PhoenixTest do
  use ExUnit.Case, async: false

  test "base/0 returns the module base based on the Mix application" do
    Mix.Project.in_project(:phoenix_sample_app, "test/fixtures/namespacing", fn _ ->
      assert Mix.Phoenix.base == "Phoenix.Sample.App"
    end)
  end

  test "modules/0 returns all modules in project" do
    assert Phoenix.Router in Mix.Phoenix.modules
  end
end
