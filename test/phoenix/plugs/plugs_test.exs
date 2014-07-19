defmodule Phoenix.PlugsTest do
  use ExUnit.Case, async: true
  alias Phoenix.Plugs


  test "plugged?/1 returns true for function plugs if included in plugs list" do
    assert Plugs.plugged?([{:action, []}], :action)
    assert Plugs.plugged?([{:dispatch, []}], :dispatch)
  end

  test "plugged?/1 returns false for function plugs if not included in plugs list" do
    refute Plugs.plugged?([], :action)
  end

  test "plugged?/1 returns true for module plugs if included in plugs list" do
    assert Plugs.plugged?([{Plugs.ContentTypeFetcher, []}], Plugs.ContentTypeFetcher)
  end

  test "plugged?/1 returns false for module plugs if not included in plugs list" do
    refute Plugs.plugged?([{Plugs.Logger, []}], Plugs.ContentTypeFetcher)
  end
end
