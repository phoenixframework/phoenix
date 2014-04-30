defmodule PhoenixConfTest.Config do
  use Phoenix.Config.App

  config :router, port: 1234
end
defmodule PhoenixConfTest.Router do
  use Phoenix.Router, port: 4000
  get "/pages/:page", Pages, :show, as: :page
end


defmodule Phoenix.Config.ConfigTest do
  use ExUnit.Case
  alias Phoenix.Config

  test "Config.for finds module based on sub Config existence" do
    assert Config.for(PhoenixConfTest.Router) == PhoenixConfTest.Config
  end

  test "Config.for falls back to Config.Fallback module if no configuration is found" do
    assert Config.for(SomeApp.Router) == Phoenix.Config.Fallback
  end
end
