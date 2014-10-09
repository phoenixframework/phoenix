defmodule Phoenix.ConfigTest do
  use ExUnit.Case, async: true
  import Phoenix.Config

  setup meta do
    config = [parsers: false, custom: true]
    Application.put_env(:phoenix, meta.test, config)
    :ok
  end

  test "loads router configuration", meta do
    config = load(meta.test)
    assert config[:parsers] == false
    assert config[:static] == [at: "/"]
    assert config[:custom] == true
  end

  test "starts an ets table as part of the router handler", meta do
    {:ok, _pid} = start_link(meta.test)
    assert :ets.info(meta.test, :name) == meta.test
    assert :ets.lookup(meta.test, :parsers) == [parsers: false]
    assert :ets.lookup(meta.test, :static)  == [static: [at: "/"]]
    assert :ets.lookup(meta.test, :custom)  == [custom: true]
  end

  test "starts a supervised and reloadable router handler", meta do
    {:ok, pid} = supervise(meta.test)
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
