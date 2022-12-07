defmodule Phoenix.ConfigTest do
  use ExUnit.Case, async: true
  import Phoenix.Config

  @defaults [static: [at: "/"]]
  @config [parsers: false, custom: true, otp_app: :phoenix_config]
  @all @config ++ @defaults

  test "reads configuration from env", meta do
    Application.put_env(:config_app, meta.test, @config)
    config = from_env(:config_app, meta.test, [static: true])
    assert config[:parsers] == false
    assert config[:custom]  == true
    assert config[:static]  == true
  end

  test "starts an ets table as part of the module", meta do
    {:ok, _pid} = start_link({meta.test, @all, @defaults, []})
    assert :ets.info(meta.test, :name) == meta.test
    assert :ets.lookup(meta.test, :parsers) == [parsers: false]
    assert :ets.lookup(meta.test, :static)  == [static: [at: "/"]]
    assert :ets.lookup(meta.test, :custom)  == [custom: true]
  end

  test "raises with warning about compile time when table not started" do
    assert_raise RuntimeError,
                 "could not find ets table for endpoint Fooz. Make sure your endpoint is started and note you cannot access endpoint functions at compile-time",
                 fn -> cache(Fooz, :foo, fn _ -> {:nocache, :bar} end) end
  end

  test "can change configuration", meta do
    {:ok, pid} = start_link({meta.test, @all, @defaults, []})
    ref = Process.monitor(pid)

    # Nothing changed
    config_change(meta.test, [], [])
    assert :ets.lookup(meta.test, :parsers) == [parsers: false]
    assert :ets.lookup(meta.test, :static)  == [static: [at: "/"]]
    assert :ets.lookup(meta.test, :custom)  == [custom: true]

    # Something changed
    config_change(meta.test, [{meta.test, parsers: true}], [])
    assert :ets.lookup(meta.test, :parsers) == [parsers: true]
    assert :ets.lookup(meta.test, :static)  == [static: [at: "/"]]
    assert :ets.lookup(meta.test, :custom)  == []

    # Module removed
    config_change(meta.test, [], [meta.test])

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    assert :ets.info(meta.test, :name) == :undefined
  end

  test "can cache", meta do
    {:ok, _pid} = start_link({meta.test, @all, @defaults, []})

    assert cache(meta.test, :__hello__, fn _ -> {:nocache, 1} end) == 1
    assert cache(meta.test, :__hello__, fn _ -> {:cache, 2} end) == 2
    assert cache(meta.test, :__hello__, fn _ -> {:cache, 3} end) == 2
    assert cache(meta.test, :__hello__, fn _ -> {:nocache, 3} end) == 2

    # Cache is reloaded on config_change
    config_change(meta.test, [{meta.test, []}], [])
    assert cache(meta.test, :__hello__, fn _ -> {:nocache, 4} end) == 4
    assert cache(meta.test, :__hello__, fn _ -> {:cache, 5} end) == 5
    assert cache(meta.test, :__hello__, fn _ -> {:cache, 6} end) == 5

    # Cache is cleaned on clear_cache
    clear_cache(meta.test)
    assert cache(meta.test, :__hello__, fn _ -> {:nocache, 7} end) == 7
    assert cache(meta.test, :__hello__, fn _ -> {:cache, 8} end) == 8
    assert cache(meta.test, :__hello__, fn _ -> {:cache, 9} end) == 8
  end
end
