defmodule Phoenix.PubSub.LocalTest do
  use ExUnit.Case, async: true
  alias Phoenix.PubSub

  setup do
    PubSub.Local.start_link(:localpub)
    :ok
  end

  test "subscribe/2 joins a pid to a topic and broadcast/2 sends messages" do
    # subscribe
    pid = spawn fn -> :timer.sleep(:infinity) end
    assert PubSub.Local.subscribers(:localpub, "foo") |> Enum.to_list == []
    :ok = PubSub.Local.subscribe(:localpub, self, "foo")
    :ok = PubSub.Local.subscribe(:localpub, pid, "foo")
    :ok = PubSub.Local.subscribe(:localpub, self, "bar")
    assert PubSub.Local.subscribers(:localpub, "foo") |> Enum.to_list |> Enum.sort
      == Enum.sort([self, pid])
    assert PubSub.Local.subscribers(:localpub, "bar") |> Enum.to_list == [self]
    assert PubSub.Local.list(:localpub) |> Enum.sort == ["bar", "foo"]

    # broadcast
    :ok = PubSub.Local.broadcast(:localpub, "foo", :hellofoo)
    assert_received :hellofoo
    assert Process.info(pid)[:messages] == [:hellofoo]
    :ok = PubSub.Local.broadcast(:localpub, "bar", :hellobar)
    assert_received :hellobar
    assert Process.info(pid)[:messages] == [:hellofoo]
    :no_topic = PubSub.Local.broadcast(:localpub, "ksfjlfsf", :hellobar)
    assert Process.info(self)[:messages] == []
  end

  test "unsubscribe/2 leaves group and removes topics when last pid leaves" do
    pid = spawn fn -> :timer.sleep(:infinity) end
    :ok = PubSub.Local.subscribe(:localpub, self, "topic1")
    :ok = PubSub.Local.subscribe(:localpub, pid, "topic1")
    assert PubSub.Local.subscribers(:localpub, "topic1") |> Enum.to_list |> Enum.sort
      == Enum.sort([self, pid])
    :ok = PubSub.Local.unsubscribe(:localpub, self, "topic1")
    assert PubSub.Local.subscribers(:localpub, "topic1") |> Enum.to_list == [pid]

    # garbage collection
    assert PubSub.Local.list(:localpub) == ["topic1"]
    :ok = PubSub.Local.unsubscribe(:localpub, pid, "topic1")
    assert PubSub.Local.subscribers(:localpub, "topic1") |> Enum.to_list == []
    assert PubSub.Local.list(:localpub) == []
  end

  test "unsubscribe/2 when not a subscriber and topic not exists" do
    pid = spawn fn -> :timer.sleep(:infinity) end
    :ok = PubSub.Local.subscribe(:localpub, pid, "topic3")
    :ok = PubSub.Local.unsubscribe(:localpub, self, "topic3")
    assert PubSub.Local.subscribers(:localpub, "topic3") |> Enum.to_list == [pid]

    :ok = PubSub.Local.unsubscribe(:localpub, pid, "notexists")
    assert PubSub.Local.subscribers(:localpub, "notexists") |> Enum.to_list == []
  end

  test "pid is removed when DOWN and topic dropped if last subscriber" do
    pid = spawn fn -> :timer.sleep(:infinity) end
    :ok = PubSub.Local.subscribe(:localpub, self, "topic5")
    :ok = PubSub.Local.subscribe(:localpub, pid, "topic5")
    :ok = PubSub.Local.subscribe(:localpub, pid, "topic6")
    assert PubSub.Local.subscribers(:localpub, "topic6") |> Enum.to_list == [pid]
    assert PubSub.Local.subscribers(:localpub, "topic5") |> Enum.to_list |> Enum.sort
      == Enum.sort([self, pid])
    Process.exit(pid, :kill)
    refute Process.alive?(pid)

    assert PubSub.Local.subscribers(:localpub, "topic5") |> Enum.to_list |> Enum.sort
      == Enum.sort([self])

    # garbage collection
    assert PubSub.Local.list(:localpub) == ["topic5"]
  end

  test "when subscriber leaves last topic, it is demonitored and removed" do
    :ok = PubSub.Local.subscribe(:localpub, self, "topic7")
    :ok = PubSub.Local.subscribe(:localpub, self, "topic8")
    {:ok, topics} = PubSub.Local.subscription(:localpub, self)
    assert topics |> Enum.to_list |> Enum.sort
      == ["topic7", "topic8"]

    :ok = PubSub.Local.unsubscribe(:localpub, self, "topic7")
    {:ok, topics} = PubSub.Local.subscription(:localpub, self)
    assert topics |> Enum.to_list |> Enum.sort
      == ["topic8"]

    :ok = PubSub.Local.unsubscribe(:localpub, self, "topic8")
    assert PubSub.Local.subscription(:localpub, self) == :error
  end
end
