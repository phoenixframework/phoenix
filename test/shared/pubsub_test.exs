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

  defp subscribers(config, topic) do
    Enum.reduce(0..(config.pool_size - 1), [], fn shard, acc ->
      acc ++ Local.subscribers(config.pubsub, topic, shard)
    end)
  end

  defp spawn_pid do
    {:ok, pid} = Task.start(fn -> :timer.sleep(:infinity) end)
    pid
  end

  defp each_shard(config, func) do
    for shard <- 0..(config.pool_size - 1), do: func.(shard)
  end

  defp kill_and_wait(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, _, _, _}
  end

  setup config do
    size = config[:pool_size] || 1
    adapter = Application.get_env(:phoenix, :pubsub_test_adapter)
    {:ok, _} = adapter.start_link(config.test, pool_size: size)
    {:ok, %{pubsub: config.test,
            pool_size: size}}
  end

  for size <- [1, 8] do
    @tag pool_size: size
    test "pool #{size}: subscribe and unsubscribe", config do
      pid = spawn_pid()
      assert subscribers(config, "topic4") |> length == 0
      assert PubSub.subscribe(config.test, pid, "topic4")
      assert subscribers(config, "topic4") == [pid]
      assert PubSub.unsubscribe(config.test, pid, "topic4")
      assert subscribers(config, "topic4") |> length == 0
    end

    @tag pool_size: size
    test "pool #{size}: subscribe/3 with link does not down adapter", config do
      pid = spawn_pid()
      assert PubSub.subscribe(config.test, pid, "topic4", link: true)

      kill_and_wait(pid)
      each_shard(config, fn shard ->
        local = Process.whereis(Local.local_name(config.pubsub, shard))
        assert Process.alive?(local)
      end)

      assert Local.subscription(config.pubsub, config.pool_size, pid) == []
      assert subscribers(config, "topic4") |> length == 0
    end

    @tag pool_size: size
    test "pool #{size}: subscribe/3 with link downs subscriber", config do
      pid = spawn_pid()
      non_linked_pid1 = spawn_pid()
      non_linked_pid2 = spawn_pid()

      assert PubSub.subscribe(config.test, pid, "topic4", link: true)
      assert PubSub.subscribe(config.test, non_linked_pid1, "topic4")
      assert PubSub.subscribe(config.test, non_linked_pid2, "topic4", link: false)

      each_shard(config, fn shard ->
        kill_and_wait(Process.whereis(Local.local_name(config.pubsub, shard)))
      end)

      refute Process.alive?(pid)
      assert Process.alive?(non_linked_pid1)
      assert Process.alive?(non_linked_pid2)
    end

    @tag pool_size: size
    test "pool #{size}: broadcast/3 and broadcast!/3 publishes message to each subscriber", config do
      PubSub.subscribe(config.test, self, "topic9")
      :ok = PubSub.broadcast(config.test, "topic9", :ping)
      assert_receive :ping
      :ok = PubSub.broadcast!(config.test, "topic9", :ping)
      assert_receive :ping
    end

    @tag pool_size: size
    test "pool #{size}: broadcast/3 does not publish message to other topic subscribers", config do
      PubSub.subscribe(config.test, self, "topic9")

      Enum.each 0..10, fn _ ->
        PubSub.subscribe(config.test, spawn_pid(), "topic10")
      end

      :ok = PubSub.broadcast(config.test, "topic10", :ping)
      refute_received :ping
    end

    @tag pool_size: size
    test "pool #{size}: broadcast_from/4 and broadcast_from!/4 skips sender", config do
      PubSub.subscribe(config.test, self, "topic11")

      PubSub.broadcast_from(config.test, self, "topic11", :ping)
      refute_received :ping

      PubSub.broadcast_from!(config.test, self, "topic11", :ping)
      refute_received :ping
    end
  end
end
