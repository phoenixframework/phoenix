defmodule Phoenix.PubSub.LocalTest do
  use ExUnit.Case, async: true
  alias Phoenix.PubSub

  setup do
    PubSub.Local.start_link
    :ok
  end

  test "subscribe/2 joins a pid to a topic and broadcast/2 sends messages" do
    # subscribe
    pid = spawn fn -> :timer.sleep(10000) end
    assert PubSub.Local.subscribers("foo") |> Enum.to_list == []
    :ok = PubSub.Local.subscribe(self, "foo")
    :ok = PubSub.Local.subscribe(pid, "foo")
    :ok = PubSub.Local.subscribe(self, "bar")
    assert PubSub.Local.subscribers("foo") |> Enum.to_list |> Enum.sort
      == Enum.sort([self, pid])
    assert PubSub.Local.subscribers("bar") |> Enum.to_list == [self]
    assert PubSub.Local.list |> Enum.sort == ["bar", "foo"]

    # broadcast
    :ok = PubSub.Local.broadcast("foo", :hellofoo)
    assert_received :hellofoo
    assert Process.info(pid)[:messages] == [:hellofoo]
    :ok = PubSub.Local.broadcast("bar", :hellobar)
    assert_received :hellobar
    assert Process.info(pid)[:messages] == [:hellofoo]
    :no_topic = PubSub.Local.broadcast("ksfjlfsf", :hellobar)
    assert Process.info(self)[:messages] == []
  end

  test "unsubscribe/2 leaves group and removes topics when last pid leaves" do
    pid = spawn fn -> :timer.sleep(10000) end
    :ok = PubSub.Local.subscribe(self, "topic1")
    :ok = PubSub.Local.subscribe(pid, "topic1")
    assert PubSub.Local.subscribers("topic1") |> Enum.to_list |> Enum.sort
      == Enum.sort([self, pid])
    :ok = PubSub.Local.unsubscribe(self, "topic1")
    assert PubSub.Local.subscribers("topic1") |> Enum.to_list == [pid]

    # garbage collection
    assert PubSub.Local.list == ["topic1"]
    :ok = PubSub.Local.unsubscribe(pid, "topic1")
    assert PubSub.Local.subscribers("topic1") |> Enum.to_list == []
    assert PubSub.Local.list == []
  end

  test "unsubscribe/2 when not a subscriber and topic not exists" do
    pid = spawn fn -> :timer.sleep(10000) end
    :ok = PubSub.Local.subscribe(pid, "topic3")
    :ok = PubSub.Local.unsubscribe(self, "topic3")
    assert PubSub.Local.subscribers("topic3") |> Enum.to_list == [pid]

    :ok = PubSub.Local.unsubscribe(pid, "notexists")
    assert PubSub.Local.subscribers("notexists") |> Enum.to_list == []
  end

  test "pid is removed when DOWN and topic dropped if last subscriber" do
    pid = spawn fn -> :timer.sleep(10000) end
    :ok = PubSub.Local.subscribe(self, "topic5")
    :ok = PubSub.Local.subscribe(pid, "topic5")
    :ok = PubSub.Local.subscribe(pid, "topic6")
    assert PubSub.Local.subscribers("topic6") |> Enum.to_list == [pid]
    assert PubSub.Local.subscribers("topic5") |> Enum.to_list |> Enum.sort
      == Enum.sort([self, pid])
    Process.exit(pid, :kill)
    refute Process.alive?(pid)

    assert PubSub.Local.subscribers("topic5") |> Enum.to_list |> Enum.sort
      == Enum.sort([self])

    # garbage collection
    assert PubSub.Local.list == ["topic5"]
  end

  test "when subscriber leaves last topic, it is demonitored and removed" do
    :ok = PubSub.Local.subscribe(self, "topic7")
    :ok = PubSub.Local.subscribe(self, "topic8")
    assert PubSub.Local.subscription(self) |> Enum.to_list |> Enum.sort
      == ["topic7", "topic8"]

    :ok = PubSub.Local.unsubscribe(self, "topic7")
    assert PubSub.Local.subscription(self) |> Enum.to_list |> Enum.sort
      == ["topic8"]

    :ok = PubSub.Local.unsubscribe(self, "topic8")
    assert PubSub.Local.subscription(self) == :no_subscription
  end
end
