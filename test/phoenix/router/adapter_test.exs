defmodule Phoenix.Router.AdapterTest do
  use ExUnit.Case, async: true
  alias Phoenix.Router.Adapter

  setup meta do
    config = [parsers: false, custom: true, otp_app: :phoenix_config]
    Application.put_env(:phoenix, meta.test, config)
    :ok
  end

  test "loads router configuration", meta do
    config = Adapter.config(meta.test)
    assert config[:otp_app] == :phoenix_config
    assert config[:parsers] == false
    assert config[:static] == [at: "/"]
    assert config[:custom] == true
  end
end
