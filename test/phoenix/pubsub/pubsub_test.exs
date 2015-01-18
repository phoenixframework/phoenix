defmodule Phoenix.PubSub.PubSubTest do
  # TODO: Should be async
  use ExUnit.Case
  alias Phoenix.PubSub

  def spawn_pid do
    spawn fn ->
      receive do
      end
    end
  end

  test "#create adds topic to process group" do
    refute PubSub.exists?("topic1")
    assert PubSub.create("topic1") == :ok
    assert PubSub.exists?("topic1")
  end

  test "#create with existing group returns :ok" do
    refute PubSub.exists?("topic2")
    assert PubSub.create("topic2") == :ok
    assert PubSub.create("topic2") == :ok
    assert PubSub.exists?("topic2")
  end

  test "#delete removes process group" do
    assert PubSub.create("topic3") == :ok
    assert PubSub.exists?("topic3")
    assert PubSub.delete("topic3") == :ok
    refute PubSub.exists?("topic3")
  end

  test "#delete does not remove active process groups" do
    assert PubSub.create("topic3") == :ok
    assert PubSub.exists?("topic3")
    PubSub.subscribe(self, "topic3")
    assert PubSub.delete("topic3") == {:error, :active}
    assert PubSub.exists?("topic3")
  end

  test "#subscribers, #subscribe, #unsubscribe" do
    pid = spawn_pid
    assert PubSub.create("topic4") == :ok
    assert Enum.empty?(PubSub.subscribers("topic4"))
    assert PubSub.subscribe(pid, "topic4")
    assert PubSub.subscribers("topic4") == [pid]
    assert PubSub.unsubscribe(pid, "topic4")
    assert Enum.empty?(PubSub.subscribers("topic4"))
    Process.exit pid, :kill
  end

  test "#active? returns true if has subscribers" do
    pid = spawn_pid
    assert PubSub.create("topic5") == :ok
    assert PubSub.subscribe(pid, "topic5")
    assert PubSub.active?("topic5")
    Process.exit pid, :kill
  end

  test "#active? returns false if no subscribers" do
    assert PubSub.create("topic6") == :ok
    refute PubSub.active?("topic6")
  end

  test "topic is garbage collected if inactive" do
    # assert true == Phoenix.PubSub.Supervisor.stop
    # refute Phoenix.PubSub.Supervisor.running?
    # PubSub.Supervisor.start_link garbage_collect_after_ms = 25
    assert PubSub.create("topic7") == :ok
    assert PubSub.exists?("topic7")
    send PubSub.PG2Adapter.leader_pid, {:garbage_collect, [{:phx, "topic7"}]}
    refute PubSub.exists?("topic7")
  end

  test "topic is not garbage collected if active" do
    # Phoenix.PubSub.Supervisor.stop
    # PubSub.Supervisor.start_link garbage_collect_after_ms = 25
    pid = spawn_pid
    # PubSub.Supervisor.start_link garbage_collect_after_ms = 25
    assert PubSub.create("topic8") == :ok
    assert PubSub.exists?("topic8")
    assert PubSub.subscribe(pid, "topic8")
    send PubSub.PG2Adapter.leader_pid, {:garbage_collect, [{:phx, "topic8"}]}
    assert PubSub.exists?("topic8")
    Process.exit pid, :kill
  end

  test "#broadcast publishes message to each subscriber" do
    assert PubSub.create("topic9") == :ok
    PubSub.subscribe(self, "topic9")
    PubSub.broadcast "topic9", :ping
    assert_received :ping
  end

  test "#broadcast does not publish message to other topic subscribers" do
    pids = Enum.map 0..10, fn _ -> spawn_pid end
    assert PubSub.create("topic10") == :ok
    pids |> Enum.each(&PubSub.subscribe(&1, "topic10"))
    PubSub.broadcast "topic10", :ping
    refute_received :ping
    pids |> Enum.each(&Process.exit &1, :kill)
  end

  test "#broadcast_from does not publish to broadcaster pid when provided" do
    assert PubSub.create("topic11") == :ok
    PubSub.subscribe(self, "topic11")
    PubSub.broadcast_from self, "topic11", :ping
    refute_received :ping
  end

  test "processes automatically removed from topic when killed" do
    pid = spawn_pid
    assert PubSub.create("topic12") == :ok
    assert PubSub.subscribe(pid, "topic12")
    assert PubSub.subscribers("topic12") == [pid]
    Process.exit pid, :kill
    :timer.sleep 10 # wait until pg2 removes dead pid
    assert PubSub.subscribers("topic12") == []
  end
end
