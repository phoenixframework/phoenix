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

  test "#members, #subscribe, #unsubscribe" do
    pid = spawn_pid
    assert Topic.create("topic4") == :ok
    assert Enum.empty?(Topic.members("topic4"))
    assert Topic.subscribe("topic4", pid)
    assert Topic.members("topic4") == [pid]
    assert Topic.unsubscribe("topic4", pid)
    assert Enum.empty?(Topic.members("topic4"))
    Process.exit pid, :kill
  end

  test "#active? returns true if has members" do
    pid = spawn_pid
    assert Topic.create("topic5") == :ok
    assert Topic.subscribe("topic5", pid)
    assert Topic.active?("topic5")
    Process.exit pid, :kill
  end

  test "#active? returns false if no members" do
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

end
