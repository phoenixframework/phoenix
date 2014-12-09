defmodule Phoenix.ConfigTest do
  use ExUnit.Case, async: true
  import Phoenix.Config

  setup meta do
    config = [parsers: false, custom: true, otp_app: :phoenix_config]
    Application.put_env(:config_app, meta.test, config)
    :ok
  end

  @defaults [static: [at: "/"]]

  test "reads configuration from env", meta do
    config = from_env(:config_app, meta.test, [static: true])
    assert config[:parsers] == false
    assert config[:custom]  == true
    assert config[:static]  == true

    assert from_env(:unknown_app, meta.test, [static: true]) ==
           [static: true]
  end

  test "starts an ets table as part of the router handler", meta do
    {:ok, _pid} = start_link(:config_app, meta.test, @defaults)
    assert :ets.info(meta.test, :name) == meta.test
    assert :ets.lookup(meta.test, :parsers) == [parsers: false]
    assert :ets.lookup(meta.test, :static)  == [static: [at: "/"]]
    assert :ets.lookup(meta.test, :custom)  == [custom: true]

    assert stop(meta.test) == :ok
    assert :ets.info(meta.test, :name) == :undefined
  end

  test "starts a supervised and reloadable router handler", meta do
    {:ok, pid} = start_supervised(:config_app, meta.test, @defaults)
    Process.link(pid)

    # Nothing changed
    reload(meta.test, [], [])
    assert :ets.lookup(meta.test, :parsers) == [parsers: false]
    assert :ets.lookup(meta.test, :static)  == [static: [at: "/"]]
    assert :ets.lookup(meta.test, :custom)  == [custom: true]

    # Something changed
    reload(meta.test, [{meta.test, parsers: true}], [])
    assert :ets.lookup(meta.test, :parsers) == [parsers: true]
    assert :ets.lookup(meta.test, :static)  == [static: [at: "/"]]
    assert :ets.lookup(meta.test, :custom)  == []

    # Router removed
    reload(meta.test, [], [meta.test])
    assert :ets.info(meta.test, :name) == :undefined
  end

  test "supports reloadable caches", meta do
    {:ok, pid} = start_supervised(:config_app, meta.test, @defaults)
    Process.link(pid)

    assert cache(meta.test, :__hello__, fn _ -> 1 end) == 1
    assert cache(meta.test, :__hello__, fn _ -> 2 end) == 1
    assert cache(meta.test, :__hello__, fn _ -> 3 end) == 1

    reload(meta.test, [{meta.test, []}], [])
    assert cache(meta.test, :__hello__, fn _ -> 4 end) == 4
  end
end
