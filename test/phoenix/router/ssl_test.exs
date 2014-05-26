defmodule PhoenixSSLTest.Config do
  use Phoenix.Config.App

  config :router, port: 71107,
                  ssl: true,
                  keyfile:  Path.expand("../../fixtures/ssl/key.pem", __DIR__),
                  certfile: Path.expand("../../fixtures/ssl/cert.pem", __DIR__)

end

defmodule PhoenixSSLTest.Router do
  use Phoenix.Router
  get "/pages/:page", Pages, :show, as: :page
end

defmodule Phoenix.Router.SSLTest do
  use ExUnit.Case
  alias Phoenix.Adapters.Cowboy
  alias Phoenix.Router.Options

  test "merge port number into options" do
    options = Options.merge([], [], PhoenixSSLTest.Router, Cowboy)
    assert options[:port] == 71107

    options = Options.merge([], [], PhoenixSSLTest.Router, Cowboy)
    assert options[:port] == 71107
    assert options[:ssl] == true
    assert File.exists? options[:keyfile]
    assert File.exists? options[:certfile]
  end
end

