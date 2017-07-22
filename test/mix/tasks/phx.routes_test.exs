Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule PhoenixTestWeb.Router do
  use Phoenix.Router
  get "/", PageController, :index, as: :page
end

defmodule PhoenixTestOld.Router do
  use Phoenix.Router
  get "/old", PageController, :index, as: :page
end


defmodule Mix.Tasks.Phx.RoutesTest do
  use ExUnit.Case, async: true

  test "format routes for specific router" do
    Mix.Tasks.Phx.Routes.run(["PhoenixTestWeb.Router"])
    assert_received {:mix_shell, :info, [routes]}
    assert routes =~ "page_path  GET  /  PageController :index"
  end

  test "prints error when explicit router cannot be found" do
    assert_raise Mix.Error, "the provided router, Foo.UnknownBar.CantFindBaz, does not exist", fn ->
      Mix.Tasks.Phx.Routes.run(["Foo.UnknownBar.CantFindBaz"])
    end
  end

  test "prints error when implicit router cannot be found" do
    assert_raise Mix.Error, ~r/no router found at FooWeb.Router or Foo.Router/, fn ->
      Mix.Tasks.Phx.Routes.run([], Foo)
    end
  end

  test "implicit router detection for web namescape" do
    Mix.Tasks.Phx.Routes.run([], PhoenixTest)
    assert_received {:mix_shell, :info, [routes]}
    assert routes =~ "page_path  GET  /  PageController :index"
  end

  test "implicit router detection fallback for old namescape" do
    Mix.Tasks.Phx.Routes.run([], PhoenixTestOld)
    assert_received {:mix_shell, :info, [routes]}
    assert routes =~ "page_path  GET  /old  PageController :index"
  end
end
