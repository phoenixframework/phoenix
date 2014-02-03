defmodule Mix.Tasks.Phoenix.RoutesTest do
  use ExUnit.Case

  defmodule Elixir.Phoenix.Config.Router do
    use Phoenix.Router

    get "/", Phoenix.Controllers.Pages, :index, as: :page
  end

  test "format default router routes" do
    assert(Mix.Tasks.Phoenix.Routes.run([]) == :ok)
  end

  defmodule Elixir.TestApp.Router do
    use Phoenix.Router

    get "/", Phoenix.Controllers.Pages, :index, as: :page
  end

  test "format routes for specific router" do
    assert(Mix.Tasks.Phoenix.Routes.run(["TestApp.Router"]) == :ok)
  end
end
