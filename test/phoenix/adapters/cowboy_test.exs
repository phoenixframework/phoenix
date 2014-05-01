defmodule Phoenix.Adapters.CowboyTest do
  use ExUnit.Case, async: true
  alias Phoenix.Adapters.Cowboy

  test "only modifies dispatch option" do
    options = [port: 5000]
    assert Cowboy.merge_options(options, [], Phoenix)[:port] == 5000
  end

  test "add users dispatch directly to the options" do
    options = Cowboy.merge_options([dispatch: [{:hello}]], [], Phoenix)
    assert {:hello} in options[:dispatch][:_]
  end

  test "add dispatch_options to the list" do
    options = Cowboy.merge_options([], [:my_dispatch], Phoenix)
    assert :my_dispatch in options[:dispatch][:_]
  end

  test "adds default plug adapter and points to our module" do
    options = Cowboy.merge_options([], [], Phoenix)
    assert options[:dispatch][:_] == [{:_, Plug.Adapters.Cowboy.Handler, {Phoenix, []}}]
  end
end
