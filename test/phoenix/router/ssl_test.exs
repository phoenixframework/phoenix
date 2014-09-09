defmodule Phoenix.Router.SSLTest do
  use ExUnit.Case, async: true
  alias Phoenix.Adapters.Cowboy
  alias Phoenix.Router.Options

  defmodule Router do
    use Phoenix.Router
    get "/pages/:page", Pages, :show, as: :page
  end

  Application.put_env(:phoenix, Router, [
    port: "71107",
    ssl: true,
    keyfile:  Path.expand("../../fixtures/ssl/key.pem", __DIR__),
    certfile: Path.expand("../../fixtures/ssl/cert.pem", __DIR__)
  ])

  test "merge port number into options" do
    options = Options.merge([], [], Router, Cowboy)
    assert options[:port] == 71107

    options = Options.merge([], [], Router, Cowboy)
    assert options[:port] == 71107
    assert options[:ssl] == true
    assert File.exists? options[:keyfile]
    assert File.exists? options[:certfile]
  end
end

