defmodule Phoenix.LocalTest do
  use ExUnit.Case, async: true

  alias Phoenix.PubSub.Local
  alias Phoenix.PubSub.GC

  setup config do
    local = :"#{config.test}_local"
    gc    = :"#{config.test}_gc"
    {:ok, _} = Local.start_link(local, gc)
    {:ok, _} = GC.start_link(gc, local)
    {:ok, local: local, gc: gc}
  end

  test "subscribe/2 joins a pid to a topic and broadcast/2 sends messages", config do
    # subscribe
    pid = spawn fn -> :timer.sleep(:infinity) end
    assert Local.subscribers(config.local, "foo") == []
    assert :ok = Local.subscribe(config.local, self, "foo")
    assert :ok = Local.subscribe(config.local, pid, "foo")
    assert :ok = Local.subscribe(config.local, self, "bar")

    # broadcast
    assert :ok = Local.broadcast(config.local, :none, "foo", :hellofoo)
    assert_received :hellofoo
    assert Process.info(pid)[:messages] == [:hellofoo]

    assert :ok = Local.broadcast(config.local, :none, "bar", :hellobar)
    assert_received :hellobar
    assert Process.info(pid)[:messages] == [:hellofoo]

    assert :ok = Local.broadcast(config.local, :none, "unknown", :hellobar)
    assert Process.info(self)[:messages] == []
  end

  test "unsubscribe/2 leaves group", config do
    pid = spawn fn -> :timer.sleep(:infinity) end
    assert :ok = Local.subscribe(config.local, self, "topic1")
    assert :ok = Local.subscribe(config.local, pid, "topic1")

    assert Local.subscribers(config.local, "topic1") == [self, pid]
    assert :ok = Local.unsubscribe(config.local, self, "topic1")
    assert Local.subscribers(config.local, "topic1") == [pid]
  end

  test "unsubscribe/2 gargabes collect topic when there are no more subscribers", config do
    assert :ok = Local.subscribe(config.local, self, "topic1")

    assert Local.list(config.local) == ["topic1"]
    assert Local.unsubscribe(config.local, self, "topic1")

    assert Enum.count(Local.list(config.local)) == 0
    assert Enum.count(Local.subscribers(config.local, "topic1")) == 0
  end

  test "unsubscribe/2 when topic does not exists", config do
    assert :ok = Local.unsubscribe(config.local, self, "notexists")
    assert Enum.count(Local.subscribers(config.local, "notexists")) == 0
  end

  test "pid is removed when DOWN", config do
    {pid, ref} = spawn_monitor fn -> :timer.sleep(:infinity) end
    assert :ok = Local.subscribe(config.local, self, "topic5")
    assert :ok = Local.subscribe(config.local, pid, "topic5")
    assert :ok = Local.subscribe(config.local, pid, "topic6")

    Process.exit(pid,  :kill)
    assert_receive {:DOWN, ^ref, _, _, _}

    # Ensure DOWN is processed to avoid races
    GenServer.call(config.gc, {})
    GenServer.call(config.gc, {})
 
    assert Local.subscription(config.local, pid) == []
    assert Local.subscribers(config.local, "topic5") == [self]
    assert Local.subscribers(config.local, "topic6") == []

    # Assert topic was also garbage collected
    assert Local.list(config.local) == ["topic5"]
  end

  test "subscriber is demonitored when it leaves the last topic", config do
    assert :ok = Local.subscribe(config.local, self, "topic7")
    assert :ok = Local.subscribe(config.local, self, "topic8")

    topics = Local.subscription(config.local, self)
    assert Enum.sort(topics) == ["topic7", "topic8"]

    assert :ok = Local.unsubscribe(config.local, self, "topic7")
    topics = Local.subscription(config.local, self)
    assert Enum.sort(topics) == ["topic8"]

    :ok = Local.unsubscribe(config.local, self, "topic8")
    assert Local.subscription(config.local, self) == []
  end
end
