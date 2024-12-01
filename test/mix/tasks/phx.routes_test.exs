Code.require_file("../../../installer/test/mix_helper.exs", __DIR__)

defmodule PageController do
  def init(opts), do: opts
  def call(conn, _opts), do: conn

  defmodule Live do
    def init(opts), do: opts
  end
end

defmodule PhoenixTestWeb.Router do
  use Phoenix.Router
  get "/", PageController, :index, as: :page
end

defmodule PhoenixTestOld.Router do
  use Phoenix.Router
  get "/old", PageController, :index, as: :page
end

defmodule PhoenixTestLiveWeb.Router do
  use Phoenix.Router
  get "/", PageController, :index, metadata: %{mfa: {PageController.Live, :init, 1}}
end

defmodule Mix.Tasks.Phx.RoutesTest do
  use ExUnit.Case, async: true

  test "format routes for specific router" do
    Mix.Tasks.Phx.Routes.run(["PhoenixTestWeb.Router", "--no-compile"])
    assert_received {:mix_shell, :info, [routes]}
    assert routes =~ "page_path  GET  /  PageController :index"
  end

  test "prints error when explicit router cannot be found" do
    assert_raise Mix.Error,
                 "the provided router, Foo.UnknownBar.CantFindBaz, does not exist",
                 fn ->
                   Mix.Tasks.Phx.Routes.run(["Foo.UnknownBar.CantFindBaz", "--no-compile"])
                 end
  end

  test "prints error when implicit router cannot be found" do
    assert_raise Mix.Error, ~r/no router found at FooWeb.Router or Foo.Router/, fn ->
      Mix.Tasks.Phx.Routes.run(["--no-compile"], Foo)
    end
  end

  test "implicit router detection for web namespace" do
    Mix.Tasks.Phx.Routes.run(["--no-compile"], PhoenixTest)
    assert_received {:mix_shell, :info, [routes]}
    assert routes =~ "page_path  GET  /  PageController :index"
  end

  test "implicit router detection fallback for old namespace" do
    Mix.Tasks.Phx.Routes.run(["--no-compile"], PhoenixTestOld)
    assert_received {:mix_shell, :info, [routes]}
    assert routes =~ "page_path  GET  /old  PageController :index"
  end

  test "overrides module name for route with :mfa metadata" do
    Mix.Tasks.Phx.Routes.run(["PhoenixTestLiveWeb.Router", "--no-compile"])
    assert_received {:mix_shell, :info, [routes]}
    assert routes =~ "page_path  GET  /  PageController.Live :index"
  end
end
