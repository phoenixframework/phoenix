defmodule Phoenix.Endpoint.AdapterTest do
  use ExUnit.Case, async: true
  alias Phoenix.Endpoint.Adapter

  setup do
    config = [custom: true]
    Application.put_env(:phoenix, AdapterApp.Endpoint, config)
    :ok
  end

  test "loads router configuration" do
    config = Adapter.config(:phoenix, AdapterApp.Endpoint)
    assert config[:otp_app] == :phoenix
    assert config[:custom] == true
    assert config[:render_errors] == AdapterApp.ErrorView
  end
end
