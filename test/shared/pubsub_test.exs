defmodule Phoenix.PubSubTest do
  @moduledoc """
  Sets up PubSub Adapter testcases

  ## Usage

  To test a PubSub adapter, set the `:pubsub_test_adapter` on the `:phoenix`
  configuration and require this file, ie:


      # your_pubsub_adapter_test.exs
      Application.put_env(:phoenix, :pubsub_test_adapter, Phoenix.PubSub.PG2)
      Code.require_file "../deps/phoenix/test/shared/pubsub_test.exs", __DIR__

  """

  use ExUnit.Case, async: true

  alias Phoenix.PubSub
  alias Phoenix.PubSub.Local

  def spawn_pid do
    {:ok, pid} = Task.start(fn -> :timer.sleep(:infinity) end)
    pid
  end

  defp kill_and_wait(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, _, _, _}
  end

  setup config do
    adapter = Application.get_env(:phoenix, :pubsub_test_adapter)
    {:ok, _} = adapter.start_link(config.test, [])
    {:ok, local: Module.concat(config.test, Elixir.Local)}
  end

  test "subscribe and unsubscribe", config do
    pid = spawn_pid
    assert Local.subscribers(config.local, "topic4") |> length == 0
    assert PubSub.subscribe(config.test, pid, "topic4")
    assert Local.subscribers(config.local, "topic4") == [pid]
    assert PubSub.unsubscribe(config.test, pid, "topic4")
    assert Local.subscribers(config.local, "topic4") |> length == 0
  end

  test "subscribe/3 with link does not down adapter", config do
    pid   = spawn_pid()
    local = Process.whereis(config.local)
    assert PubSub.subscribe(config.test, pid, "topic4", link: true)

    kill_and_wait(pid)
    assert Process.alive?(local)
    # Ensure DOWN is processed to avoid races
    Local.unsubscribe(config.local, pid, "unknown")

    assert Local.subscription(config.local, pid) == []
    assert Local.subscribers(config.local, "topic4") |> length == 0
  end

  test "subscribe/3 with link downs subscriber", config do
    pid = spawn_pid
    non_linked_pid1 = spawn_pid
    non_linked_pid2 = spawn_pid

    assert PubSub.subscribe(config.test, pid, "topic4", link: true)
    assert PubSub.subscribe(config.test, non_linked_pid1, "topic4")
    assert PubSub.subscribe(config.test, non_linked_pid2, "topic4", link: false)

    kill_and_wait(Process.whereis(config.local))

    refute Process.alive?(pid)
    assert Process.alive?(non_linked_pid1)
    assert Process.alive?(non_linked_pid2)
  end

  test "broadcast/3 and broadcast!/3 publishes message to each subscriber", config do
    PubSub.subscribe(config.test, self, "topic9")
    :ok = PubSub.broadcast(config.test, "topic9", :ping)
    assert_receive :ping
    :ok = PubSub.broadcast!(config.test, "topic9", :ping)
    assert_receive :ping
  end

  test "broadcast/3 does not publish message to other topic subscribers", config do
    PubSub.subscribe(config.test, self, "topic9")

    Enum.each 0..10, fn _ ->
      PubSub.subscribe(config.test, spawn_pid(), "topic10")
    end

    :ok = PubSub.broadcast(config.test, "topic10", :ping)
    refute_received :ping
  end

  test "broadcast_from/4 and broadcast_from!/4 skips sender", config do
    PubSub.subscribe(config.test, self, "topic11")

    PubSub.broadcast_from(config.test, self, "topic11", :ping)
    refute_received :ping

    PubSub.broadcast_from!(config.test, self, "topic11", :ping)
    refute_received :ping
  end
end
