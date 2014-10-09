defmodule Phoenix.ConfigTest do
  use ExUnit.Case
  import Phoenix.Config

  setup meta do
    config = [parsers: false, custom: true, otp_app: :phoenix_config]
    Application.put_env(:phoenix, meta.test, config)
    :ok
  end

  test "loads router configuration", meta do
    config = load(meta.test)
    assert config[:otp_app] == :phoenix_config
    assert config[:parsers] == false
    assert config[:static] == [at: "/"]
    assert config[:custom] == true
  end

  test "loads otp_app from Mix environment", _meta do
    config = load(:whatever_router)
    assert config[:otp_app] == :phoenix
    assert config[:static] == [at: "/"]
  end

  test "starts an ets table as part of the router handler", meta do
    {:ok, _pid} = start_link(:phoenix_config, meta.test)
    assert :ets.info(meta.test, :name) == meta.test
    assert :ets.lookup(meta.test, :parsers) == [parsers: false]
    assert :ets.lookup(meta.test, :static)  == [static: [at: "/"]]
    assert :ets.lookup(meta.test, :custom)  == [custom: true]

    assert stop(meta.test) == :ok
    assert :ets.info(meta.test, :name) == :undefined
  end

  test "starts a supervised and reloadable router handler", meta do
    {:ok, pid} = supervise(:phoenix_config, meta.test)
    Process.link(pid)

    # Nothing changed
    reload([], [])
    assert :ets.lookup(meta.test, :parsers) == [parsers: false]
    assert :ets.lookup(meta.test, :static)  == [static: [at: "/"]]
    assert :ets.lookup(meta.test, :custom)  == [custom: true]

    # Something changed
    reload([{meta.test, parsers: true}], [])
    assert :ets.lookup(meta.test, :parsers) == [parsers: true]
    assert :ets.lookup(meta.test, :static)  == [static: [at: "/"]]
    assert :ets.lookup(meta.test, :custom)  == []

    # Router removed
    reload([], [meta.test])
    assert :ets.info(meta.test, :name) == :undefined
  end
end
