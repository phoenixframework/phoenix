defmodule PhoenixOptionsTest.Config do
  use Phoenix.Config.App

  config :router, port: "71107", ssl: false
end

defmodule PhoenixOptionsTest.Router do
  use Phoenix.Router
  get "/pages/:page", Pages, :show, as: :page
end

defmodule Phoenix.Router.OptionsTest do
  use ExUnit.Case
  alias Phoenix.Adapters.Cowboy
  alias Phoenix.Router.Options

  test "merge port number into options" do
    options = Options.merge([], [], PhoenixConfTest.Router, Cowboy)
    assert options[:port] == 1234

    options = Options.merge([], [], PhoenixOptionsTest.Router, Cowboy)
    assert options[:port] == 71107
    assert options[:ssl] == false
  end
end
