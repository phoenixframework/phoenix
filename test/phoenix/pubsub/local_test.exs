defmodule Phoenix.LocalTest do
  use ExUnit.Case, async: true
  alias Phoenix.PubSub.Local

  setup config do
    {:ok, _} = Local.start_link(config.test)
    :ok
  end

  test "subscribe/2 joins a pid to a topic and broadcast/2 sends messages", config do
    # subscribe
    pid = spawn fn -> :timer.sleep(:infinity) end
    assert Local.subscribers(config.test, "foo") == []
    assert :ok = Local.subscribe(config.test, self, "foo")
    assert :ok = Local.subscribe(config.test, pid, "foo")
    assert :ok = Local.subscribe(config.test, self, "bar")

    # broadcast
    assert :ok = Local.broadcast(config.test, :none, "foo", :hellofoo)
    assert_received :hellofoo
    assert Process.info(pid)[:messages] == [:hellofoo]

    assert :ok = Local.broadcast(config.test, :none, "bar", :hellobar)
    assert_received :hellobar
    assert Process.info(pid)[:messages] == [:hellofoo]

    assert :ok = Local.broadcast(config.test, :none, "unknown", :hellobar)
    assert Process.info(self)[:messages] == []
  end

  test "unsubscribe/2 leaves group", config do
    pid = spawn fn -> :timer.sleep(:infinity) end
    assert :ok = Local.subscribe(config.test, self, "topic1")
    assert :ok = Local.subscribe(config.test, pid, "topic1")

    assert Local.subscribers(config.test, "topic1") ==
           [self, pid]

    assert :ok = Local.unsubscribe(config.test, self, "topic1")
    assert Local.subscribers(config.test, "topic1") ==
           [pid]
  end

  test "unsubscribe/2 gargabes collect topic when there are no more subscribers", config do
    assert :ok = Local.subscribe(config.test, self, "topic1")

    assert Local.list(config.test) == ["topic1"]
    assert Local.unsubscribe(config.test, self, "topic1")

    assert Enum.count(Local.list(config.test)) == 0
    assert Enum.count(Local.subscribers(config.test, "topic1")) == 0
  end

  test "unsubscribe/2 when topic does not exists", config do
    assert :ok = Local.unsubscribe(config.test, self, "notexists")
    assert Enum.count(Local.subscribers(config.test, "notexists")) == 0
  end

  test "pid is removed when DOWN", config do
    {pid, ref} = spawn_monitor fn -> :timer.sleep(:infinity) end
    assert :ok = Local.subscribe(config.test, self, "topic5")
    assert :ok = Local.subscribe(config.test, pid, "topic5")
    assert :ok = Local.subscribe(config.test, pid, "topic6")

    Process.exit(pid,  :kill)
    assert_receive {:DOWN, ^ref, _, _, _}

    assert Local.subscription(config.test, pid) == :error
    assert Local.subscribers(config.test, "topic5") == [self]
    assert Local.subscribers(config.test, "topic6") == []

    # Assert topic was also garbage collected
    assert Local.list(config.test) == ["topic5"]
  end

  test "subscriber is demonitored when it leaves the last topic", config do
    assert :ok = Local.subscribe(config.test, self, "topic7")
    assert :ok = Local.subscribe(config.test, self, "topic8")

    {:ok, topics} = Local.subscription(config.test, self)
    assert Enum.sort(topics) == ["topic7", "topic8"]

    assert :ok = Local.unsubscribe(config.test, self, "topic7")
    assert {:ok, topics} = Local.subscription(config.test, self)
    assert Enum.sort(topics) == ["topic8"]

    :ok = Local.unsubscribe(config.test, self, "topic8")
    assert :error = Local.subscription(config.test, self)
  end
end
