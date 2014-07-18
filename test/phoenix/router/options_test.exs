defmodule Phoenix.Router.OptionsTest do
  use ExUnit.Case, async: false
  alias Phoenix.Adapters.Cowboy
  alias Phoenix.Router.Options
  alias Phoenix.Router.OptionsTest.PhoenixOptionsTest

  setup_all do
    Mix.Config.persist(phoenix: [
      {Router, port: 71107},
      {Router2, port: "4000", proxy_port: "80"},
    ])

    defmodule Router do
      use Phoenix.Router
      get "/pages/:page", Pages, :show, as: :page
    end

    :ok
  end

  test "merge port number into options" do
    options = Options.merge([], [], Router, Cowboy)
    assert options[:port] == 71107
    assert options[:ssl] == false
  end

  test "converts port and proxy_prot from string to int" do
    options = Options.merge([], [], Router2, Cowboy)
    assert options[:port] == 4000
    assert options[:proxy_port] == 80
  end
end
