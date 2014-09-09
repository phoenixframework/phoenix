defmodule Phoenix.Router.OptionsTest do
  use ExUnit.Case, async: false
  alias Phoenix.Adapters.Cowboy
  alias Phoenix.Router.Options

  Application.put_env(:phoenix, OptionsRouter, port: 71107)
  Application.put_env(:phoenix, OptionsRouter2, port: "4000", proxy_port: "80")

  test "merge port number into options" do
    options = Options.merge([], [], OptionsRouter, Cowboy)
    assert options[:port] == 71107
    assert options[:ssl] == false
  end

  test "converts port and proxy_port from string to int" do
    options = Options.merge([], [], OptionsRouter2, Cowboy)
    assert options[:port] == 4000
    assert options[:proxy_port] == 80
  end
end
