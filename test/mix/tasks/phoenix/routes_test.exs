defmodule Mix.Tasks.Phoenix.RoutesTest do
  use ExUnit.Case, async: false

  setup_all do
    Mix.Config.persist(phoenix: [
      {Elixir.Phoenix.RouterTest, port: 1234},
      {Elixir.TestApp.Router, port: 1234}
    ])

    defmodule Elixir.Phoenix.RouterTest do
      use Phoenix.Router

      get "/", Phoenix.Controllers.Pages, :index, as: :page
    end

    defmodule Elixir.TestApp.Router do
      use Phoenix.Router

      get "/", Phoenix.Controllers.Pages, :index, as: :page
    end

    :ok
  end

  test "format routes for specific router" do
    assert Mix.Tasks.Phoenix.Routes.run(["TestApp.Router"])
  end
end
