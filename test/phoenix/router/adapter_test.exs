defmodule Phoenix.Router.AdapterTest do
  use ExUnit.Case, async: true
  alias Phoenix.Adapters.Cowboy
  alias Phoenix.Router.Adapter

  Application.put_env(:phoenix, OptionsRouter, port: 71107)
  Application.put_env(:phoenix, OptionsRouter2, port: "4000", proxy_port: "80")
  Application.put_env(:phoenix, OptionsRouter3, [
    port: "71107",
    ssl: true,
    keyfile:  Path.expand("../../fixtures/ssl/key.pem", __DIR__),
    certfile: Path.expand("../../fixtures/ssl/cert.pem", __DIR__)
  ])

  test "merge port number into options" do
    options = Adapter.merge([], [], OptionsRouter, Cowboy)
    assert options[:port] == 71107
    assert options[:ssl] == false
  end

  test "merge port number into options with ssl" do
    options = Adapter.merge([], [], OptionsRouter3, Cowboy)
    assert options[:port] == 71107

    options = Adapter.merge([], [], OptionsRouter3, Cowboy)
    assert options[:port] == 71107
    assert options[:ssl] == true
    assert File.exists? options[:keyfile]
    assert File.exists? options[:certfile]
  end

  test "converts port and proxy_port from string to int" do
    options = Adapter.merge([], [], OptionsRouter2, Cowboy)
    assert options[:port] == 4000
    assert options[:proxy_port] == 80
  end
end
