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

  test "merge port number into options" do
    assert [port: 1234] ==
      Phoenix.Router.Options.merge([], PhoenixConfTest.Router)

    assert [port: 71107, ssl: false] ==
      Phoenix.Router.Options.merge([], PhoenixOptionsTest.Router)
  end

end
