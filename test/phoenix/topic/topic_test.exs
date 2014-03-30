defmodule Phoenix.Topic.TopicTest do
  use ExUnit.Case, async: false
  alias Phoenix.Topic

  def cleanup, do: Enum.each(0..10, &Topic.delete("topic#{&1}"))

  def spawn_pid do
    spawn fn ->
      receive do
      end
    end
  end

  setup do
    cleanup
    :ok
  end

  teardown do
    cleanup
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
    assert Topic.delete("topic3")
    refute Topic.exists?("topic3")
  end

  test "#subscribers, #subscribe, #unsubscribe" do
    pid = spawn_pid
    assert Topic.create("topic4") == :ok
    assert Enum.empty?(Topic.subscribers("topic4"))
    assert Topic.subscribe("topic4", pid)
    assert Topic.subscribers("topic4") == [pid]
    assert Topic.unsubscribe("topic4", pid)
    assert Enum.empty?(Topic.subscribers("topic4"))
    Process.exit pid, :kill
  end

  test "#active? returns true if has subscribers" do
    pid = spawn_pid
    assert Topic.create("topic5") == :ok
    assert Topic.subscribe("topic5", pid)
    assert Topic.active?("topic5")
    Process.exit pid, :kill
  end

  test "#active? returns false if no subscribers" do
    assert Topic.create("topic6") == :ok
    refute Topic.active?("topic6")
  end

  test "topic is garbage collected if inactive" do
    assert Topic.create("topic7", garbage_collect_after_ms: 25) == :ok
    assert Topic.exists?("topic7")
    :timer.sleep 50
    refute Topic.exists?("topic7")
  end

  test "topic is not garbage collected if active" do
    pid = spawn_pid
    assert Topic.create("topic8", garbage_collect_after_ms: 25) == :ok
    assert Topic.exists?("topic8")
    assert Topic.subscribe("topic8", pid)
    :timer.sleep 50
    assert Topic.exists?("topic8")
    Process.exit pid, :kill
  end

  test "#broadcast publishes message to each subscriber" do
    assert Topic.create("topic9") == :ok
    Topic.subscribe("topic9", self)
    Topic.broadcast "topic9", :ping
    assert_received :ping
  end

  test "#broadcast does not publish message to other topic subscribers" do
    pids = Enum.map 0..10, fn _ -> spawn_pid end
    assert Topic.create("topic10") == :ok
    pids |> Enum.each(&Topic.subscribe("topic10", &1))
    Topic.broadcast "topic10", :ping
    refute_received :ping
    pids |> Enum.each(&Process.exit &1, :kill)
  end

  test "processes automatically removed from topic when killed" do
    pid = spawn_pid
    assert Topic.create("topic11") == :ok
    assert Topic.subscribe("topic11", pid)
    assert Topic.subscribers("topic11") == [pid]
    Process.exit pid, :kill
    :timer.sleep 10 # wait until pg2 removes dead pid
    assert Topic.subscribers("topic11") == []
  end
end
