defmodule Phoenix.PubSub.PubSubTest do
  # TODO: Should be async
  use ExUnit.Case
  alias Phoenix.PubSub.RedisAdapter
  alias Phoenix.PubSub.PG2Adapter

  @adapters [RedisAdapter, PG2Adapter]

  def spawn_pid do
    spawn fn -> :timer.sleep(:infinity) end
  end

  for adapter <- @adapters do
    @adapter adapter
    setup_all do
      @adapter.start_link(name: @adapter)
      :ok
    end
    @server @adapter

    test "#{inspect @adapter} #subscribers, #subscribe, #unsubscribe" do
      pid = spawn_pid
      assert Enum.empty?(@adapter.subscribers(@server, "topic4"))
      assert @adapter.subscribe(@server, pid, "topic4")
      assert @adapter.subscribers(@server, "topic4") |> Enum.to_list == [pid]
      assert @adapter.unsubscribe(@server, pid, "topic4")
      assert Enum.empty?(@adapter.subscribers(@server, "topic4"))
      Process.exit pid, :kill
    end

    test "#{inspect @adapter} #broadcast publishes message to each subscriber" do
      @adapter.subscribe(@server, self, "topic9")
      assert @adapter.subscribers(@server, "topic9") |> Enum.to_list == [self]
      @adapter.broadcast(@server, "topic9", :ping)
      assert_receive :ping
    end

    test "#{inspect @adapter} #broadcast does not publish message to other topic subscribers" do
      pids = Enum.map 0..10, fn _ -> spawn_pid end
      pids |> Enum.each(&@adapter.subscribe(@server, &1, "topic10"))
      @adapter.broadcast(@server, "topic10", :ping)
      refute_receive :ping
      pids |> Enum.each(&Process.exit &1, :kill)
    end

    test "#{inspect @adapter} #broadcast_from does not publish to broadcaster pid when provided" do
      @adapter.subscribe(@server, self, "topic11")
      @adapter.broadcast_from(@server, self, "topic11", :ping)
      refute_receive :ping
    end

    test "#{inspect @adapter} processes automatically removed from topic when killed" do
      pid = spawn_pid
      assert @adapter.subscribe(@server, pid, "topic12")
      assert @adapter.subscribers(@server, "topic12") |> Enum.to_list == [pid]
      Process.exit pid, :kill
      :timer.sleep 10 # wait until adapter removes dead pid
      assert @adapter.subscribers(@server, "topic12") |> Enum.to_list == []
    end
  end
end
