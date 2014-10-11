defmodule Phoenix.Topic.TopicTest do
  use ExUnit.Case
  alias Phoenix.Topic

  def spawn_pid do
    spawn fn ->
      receive do
      end
    end
  end

  setup_all do
    :ok
  end

  test "#create adds topic to process group" do
    refute Topic.exists?("topic1")
    assert Topic.create("topic1") == :ok
    assert Topic.exists?("topic1")
  end

  test "#create with existing group returns :ok" do
    refute Topic.exists?("topic2")
    assert Topic.create("topic2") == :ok
    assert Topic.create("topic2") == :ok
    assert Topic.exists?("topic2")
  end

  test "#delete removes process group" do
    assert Topic.create("topic3") == :ok
    assert Topic.exists?("topic3")
    assert Topic.delete("topic3") == :ok
    refute Topic.exists?("topic3")
  end

  test "#delete does not remove active process groups" do
    assert Topic.create("topic3") == :ok
    assert Topic.exists?("topic3")
    Topic.subscribe(self, "topic3")
    assert Topic.delete("topic3") == {:error, :active}
    assert Topic.exists?("topic3")
  end

  test "#subscribers, #subscribe, #unsubscribe" do
    pid = spawn_pid
    assert Topic.create("topic4") == :ok
    assert Enum.empty?(Topic.subscribers("topic4"))
    assert Topic.subscribe(pid, "topic4")
    assert Topic.subscribers("topic4") == [pid]
    assert Topic.unsubscribe(pid, "topic4")
    assert Enum.empty?(Topic.subscribers("topic4"))
    Process.exit pid, :kill
  end

  test "#active? returns true if has subscribers" do
    pid = spawn_pid
    assert Topic.create("topic5") == :ok
    assert Topic.subscribe(pid, "topic5")
    assert Topic.active?("topic5")
    Process.exit pid, :kill
  end

  test "#active? returns false if no subscribers" do
    assert Topic.create("topic6") == :ok
    refute Topic.active?("topic6")
  end

  test "topic is garbage collected if inactive" do
    # assert true == Phoenix.Topic.Supervisor.stop
    # refute Phoenix.Topic.Supervisor.running?
    # Topic.Supervisor.start_link garbage_collect_after_ms = 25
    assert Topic.create("topic7") == :ok
    assert Topic.exists?("topic7")
    send Topic.Server.leader_pid, {:garbage_collect, [{:phx, "topic7"}]}
    refute Topic.exists?("topic7")
  end

  test "topic is not garbage collected if active" do
    # Phoenix.Topic.Supervisor.stop
    # Topic.Supervisor.start_link garbage_collect_after_ms = 25
    pid = spawn_pid
    # Topic.Supervisor.start_link garbage_collect_after_ms = 25
    assert Topic.create("topic8") == :ok
    assert Topic.exists?("topic8")
    assert Topic.subscribe(pid, "topic8")
    send Topic.Server.leader_pid, {:garbage_collect, [{:phx, "topic8"}]}
    assert Topic.exists?("topic8")
    Process.exit pid, :kill
  end

  test "#broadcast publishes message to each subscriber" do
    assert Topic.create("topic9") == :ok
    Topic.subscribe(self, "topic9")
    Topic.broadcast "topic9", :ping
    assert_received :ping
  end

  test "#broadcast does not publish message to other topic subscribers" do
    pids = Enum.map 0..10, fn _ -> spawn_pid end
    assert Topic.create("topic10") == :ok
    pids |> Enum.each(&Topic.subscribe(&1, "topic10"))
    Topic.broadcast "topic10", :ping
    refute_received :ping
    pids |> Enum.each(&Process.exit &1, :kill)
  end

  test "#broadcast_from does not publish to broadcaster pid when provided" do
    assert Topic.create("topic11") == :ok
    Topic.subscribe(self, "topic11")
    Topic.broadcast_from self, "topic11", :ping
    refute_received :ping
  end

  test "processes automatically removed from topic when killed" do
    pid = spawn_pid
    assert Topic.create("topic12") == :ok
    assert Topic.subscribe(pid, "topic12")
    assert Topic.subscribers("topic12") == [pid]
    Process.exit pid, :kill
    :timer.sleep 10 # wait until pg2 removes dead pid
    assert Topic.subscribers("topic12") == []
  end
end
