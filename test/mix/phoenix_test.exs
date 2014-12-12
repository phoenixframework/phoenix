defmodule Mix.PhoenixTest do
  use ExUnit.Case, async: true

  test "base/0 returns the module base based on the Mix application" do
    assert Mix.Phoenix.base == "Phoenix"
  end

  test "endpoints/0 returns the endpoints based on the Mix application" do
    assert Mix.Phoenix.endpoints([]) == [Phoenix.Endpoint]
    assert Mix.Phoenix.endpoints(["Hello.Endpoint"]) == [Hello.Endpoint]
  end

  test "modules/0 returns all modules in project" do
    assert Phoenix.Router in Mix.Phoenix.modules
  end
end
