defmodule Phoenix.Router.AdapterTest do
  use ExUnit.Case, async: true
  alias Phoenix.Router.Adapter

  setup do
    config = [parsers: false, custom: true, otp_app: :phoenix_config]
    Application.put_env(:phoenix, AdapterApp.Router, config)
    :ok
  end

  test "loads router configuration" do
    config = Adapter.config(AdapterApp.Router)
    assert config[:otp_app] == :phoenix_config
    assert config[:parsers] == false
    assert config[:static] == [at: "/"]
    assert config[:custom] == true
    assert config[:render_errors] == AdapterApp.ErrorView
  end
end
