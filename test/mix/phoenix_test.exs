defmodule Mix.PhoenixTest do
  use ExUnit.Case, async: true

  test "router/0 returns the router based on the Mix application" do
    assert Mix.Phoenix.router == Phoenix.Router
  end

  test "endpoint/0 returns the router based on the Mix application" do
    assert Mix.Phoenix.endpoint == Phoenix.Endpoint
  end

  test "modules/0 returns all modules in project" do
    assert Phoenix.Router in Mix.Phoenix.modules
  end
end
