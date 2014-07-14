defmodule Phoenix.Router.OptionsTest do
  use ExUnit.Case, async: false
  alias Phoenix.Adapters.Cowboy
  alias Phoenix.Router.Options
  alias Phoenix.Router.OptionsTest.PhoenixOptionsTest

  setup_all do
    Mix.Config.persist(phoenix: [
      routers: [
        [endpoint: PhoenixOptionsTest.Router, port: 71107],
      ]
    ])

    defmodule PhoenixOptionsTest.Router do
      use Phoenix.Router
      get "/pages/:page", Pages, :show, as: :page
    end

    :ok
  end

  test "merge port number into options" do
    options = Options.merge([], [], PhoenixOptionsTest.Router, Cowboy)
    assert options[:port] == 71107
    assert options[:ssl] == false
  end
end
