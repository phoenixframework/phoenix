defmodule Phoenix.PubSub.PubSubTest do
  # TODO: Should be async
  use ExUnit.Case
  alias Phoenix.PubSub
  alias Phoenix.PubSub.RedisAdapter
  alias Phoenix.PubSub.PG2Adapter

  @adapters [RedisAdapter, PG2Adapter]

  def spawn_pid do
    spawn fn -> :timer.sleep(:infinity) end
  end

  for adapter <- @adapters do
    @adapter adapter
    unless @adapter == PG2Adapter do
      setup_all do
        @adapter.start_link()
        :ok
      end
    end

    # test "#{inspect @adapter} #create adds topic to process group" do
    #   refute PubSub.exists?("topic1", @adapter)
    #   assert PubSub.create("topic1", @adapter) == :ok
    #   assert PubSub.exists?("topic1", @adapter)
    # end

    # test "#{inspect @adapter} #create with existing group returns :ok" do
    #   refute PubSub.exists?("topic2", @adapter)
    #   assert PubSub.create("topic2", @adapter) == :ok
    #   assert PubSub.create("topic2", @adapter) == :ok
    #   assert PubSub.exists?("topic2", @adapter)
    # end

    # test "#{inspect @adapter} #delete removes process group" do
    #   assert PubSub.create("topic3", @adapter) == :ok
    #   assert PubSub.exists?("topic3", @adapter)
    #   assert PubSub.delete("topic3", @adapter) == :ok
    #   refute PubSub.exists?("topic3", @adapter)
    # end

    # test "#{inspect @adapter} #delete does not remove active process groups" do
    #   assert PubSub.create("topic3", @adapter) == :ok
    #   assert PubSub.exists?("topic3", @adapter)
    #   PubSub.subscribe(self, "topic3", @adapter)
    #   assert PubSub.delete("topic3", @adapter) == {:error, :active}
    #   assert PubSub.exists?("topic3", @adapter)
    # end

    test "#{inspect @adapter} #subscribers, #subscribe, #unsubscribe" do
      pid = spawn_pid
      assert Enum.empty?(PubSub.subscribers("topic4", @adapter))
      assert PubSub.subscribe(pid, "topic4", @adapter)
      assert PubSub.subscribers("topic4", @adapter) |> Enum.to_list == [pid]
      assert PubSub.unsubscribe(pid, "topic4", @adapter)
      assert Enum.empty?(PubSub.subscribers("topic4", @adapter))
      Process.exit pid, :kill
    end

    # test "#{inspect @adapter} #active? returns true if has subscribers" do
    #   pid = spawn_pid
    #   assert PubSub.create("topic5", @adapter) == :ok
    #   assert PubSub.subscribe(pid, "topic5", @adapter)
    #   assert PubSub.active?("topic5", @adapter)
    #   Process.exit pid, :kill
    # end

    # test "#{inspect @adapter} #active? returns false if no subscribers" do
    #   assert PubSub.create("topic6", @adapter) == :ok
    #   refute PubSub.active?("topic6", @adapter)
    # end

    # test "#{inspect @adapter} topic is garbage collected if inactive" do
    #   # assert true == Phoenix.PubSub.Supervisor.stop
    #   # refute Phoenix.PubSub.Supervisor.running?
    #   # PubSub.Supervisor.start_link garbage_collect_after_ms = 25
    #   assert PubSub.create("topic7", @adapter) == :ok
    #   assert PubSub.exists?("topic7", @adapter)
    #   send @adapter.server_pid(), {:garbage_collect, [@adapter.namespace_topic("topic7")]}
    #   refute PubSub.exists?("topic7", @adapter)
    # end

    # test "#{inspect @adapter} topic is not garbage collected if active" do
    #   # Phoenix.PubSub.Supervisor.stop
    #   # PubSub.Supervisor.start_link garbage_collect_after_ms = 25
    #   pid = spawn_pid
    #   # PubSub.Supervisor.start_link garbage_collect_after_ms = 25
    #   assert PubSub.create("topic8", @adapter) == :ok
    #   assert PubSub.exists?("topic8", @adapter)
    #   assert PubSub.subscribe(pid, "topic8", @adapter)
    #   send @adapter.server_pid(), {:garbage_collect, [@adapter.namespace_topic("topic8")]}
    #   assert PubSub.exists?("topic8", @adapter)
    #   Process.exit pid, :kill
    # end

    test "#{inspect @adapter} #broadcast publishes message to each subscriber" do
      PubSub.subscribe(self, "topic9", @adapter)
      assert PubSub.subscribers("topic9", @adapter) |> Enum.to_list == [self]
      PubSub.broadcast("topic9", :ping, @adapter)
      assert_receive :ping
    end

    test "#{inspect @adapter} #broadcast does not publish message to other topic subscribers" do
      pids = Enum.map 0..10, fn _ -> spawn_pid end
      pids |> Enum.each(&PubSub.subscribe(&1, "topic10", @adapter))
      PubSub.broadcast("topic10", :ping, @adapter)
      refute_receive :ping
      pids |> Enum.each(&Process.exit &1, :kill)
    end

    test "#{inspect @adapter} #broadcast_from does not publish to broadcaster pid when provided" do
      PubSub.subscribe(self, "topic11", @adapter)
      PubSub.broadcast_from(self, "topic11", :ping, @adapter)
      refute_receive :ping
    end

    test "#{inspect @adapter} processes automatically removed from topic when killed" do
      pid = spawn_pid
      assert PubSub.subscribe(pid, "topic12", @adapter)
      assert PubSub.subscribers("topic12", @adapter) |> Enum.to_list == [pid]
      Process.exit pid, :kill
      :timer.sleep 10 # wait until adapter removes dead pid
      assert PubSub.subscribers("topic12", @adapter) |> Enum.to_list == []
    end
  end
end
