defmodule Phoenix.Adapters.CowboyTest do
  use ExUnit.Case, async: true
  alias Phoenix.Adapters.Cowboy

  test "only modifies dispatch option" do
    options = ListDict.new port: 5000
    assert Cowboy.setup_options(Pheonix, options, [])[:port] == 5000
  end

  test "add users dispatch directly to the options" do
    options = Cowboy.setup_options(Phoenix, [dispatch: [{:hello}]], [])
    assert {:hello} in options[:dispatch][:_]
  end

  test "add dispatch_options to the list" do
    options = Cowboy.setup_options(Phoenix, [], [:my_dispatch])
    assert :my_dispatch in options[:dispatch][:_]
  end

  test "adds default plug adapter and points to our module" do
    options = Cowboy.setup_options(Phoenix, [], [])
    assert options[:dispatch][:_] == [{:_, Plug.Adapters.Cowboy.Handler, {Phoenix, []}}]
  end
end
