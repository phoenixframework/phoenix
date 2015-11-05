defmodule Phoenix.LocalTest do
  use ExUnit.Case, async: true

  alias Phoenix.PubSub.Local

  @pool_size 1

  setup config do
    {:ok, _} = Phoenix.PubSub.LocalSupervisor.start_link(config.test, @pool_size, [])
    {:ok, %{pubsub: config.test, gc: Local.gc_name(config.test, 0)}}
  end

  test "subscribe/2 joins a pid to a topic and broadcast/2 sends messages", config do
    # subscribe
    pid = spawn fn -> :timer.sleep(:infinity) end
    assert Local.subscribers(config.pubsub, "foo", 0) == []
    assert :ok = Local.subscribe(config.pubsub, @pool_size, self, "foo")
    assert :ok = Local.subscribe(config.pubsub, @pool_size, pid, "foo")
    assert :ok = Local.subscribe(config.pubsub, @pool_size, self, "bar")

    # broadcast
    assert :ok = Local.broadcast(config.pubsub, :none, @pool_size, "foo", :hellofoo)
    assert_received :hellofoo
    assert Process.info(pid)[:messages] == [:hellofoo]

    assert :ok = Local.broadcast(config.pubsub, :none, @pool_size, "bar", :hellobar)
    assert_received :hellobar
    assert Process.info(pid)[:messages] == [:hellofoo]

    assert :ok = Local.broadcast(config.pubsub, :none, @pool_size, "unknown", :hellobar)
    assert Process.info(self)[:messages] == []
  end

  test "unsubscribe/2 leaves group", config do
    pid = spawn fn -> :timer.sleep(:infinity) end
    assert :ok = Local.subscribe(config.pubsub, @pool_size, self, "topic1")
    assert :ok = Local.subscribe(config.pubsub, @pool_size, pid, "topic1")

    assert Local.subscribers(config.pubsub, "topic1", 0) == [self, pid]
    assert :ok = Local.unsubscribe(config.pubsub, @pool_size, self, "topic1")
    assert Local.subscribers(config.pubsub, "topic1", 0) == [pid]
  end

  test "unsubscribe/2 gargabes collect topic when there are no more subscribers", config do
    assert :ok = Local.subscribe(config.pubsub, @pool_size, self, "topic1")

    assert Local.list(config.pubsub, 0) == ["topic1"]
    assert Local.unsubscribe(config.pubsub, @pool_size, self, "topic1")

    assert Enum.count(Local.list(config.pubsub, 0)) == 0
    assert Enum.count(Local.subscribers(config.pubsub, "topic1", 0)) == 0
  end

  test "unsubscribe/2 when topic does not exists", config do
    assert :ok = Local.unsubscribe(config.pubsub, @pool_size, self, "notexists")
    assert Enum.count(Local.subscribers(config.pubsub, "notexists", 0)) == 0
  end

  test "pid is removed when DOWN", config do
    {pid, ref} = spawn_monitor fn -> :timer.sleep(:infinity) end
    assert :ok = Local.subscribe(config.pubsub, @pool_size, self, "topic5")
    assert :ok = Local.subscribe(config.pubsub, @pool_size, pid, "topic5")
    assert :ok = Local.subscribe(config.pubsub, @pool_size, pid, "topic6")

    Process.exit(pid,  :kill)
    assert_receive {:DOWN, ^ref, _, _, _}

    # Ensure DOWN is processed to avoid races
    Local.subscribe(config.pubsub, @pool_size, pid, "unknown")
    Local.unsubscribe(config.pubsub, @pool_size, pid, "unknown")
    GenServer.call(config.gc, :noop)

    assert Local.subscription(config.pubsub, @pool_size, pid) == []
    assert Local.subscribers(config.pubsub, "topic5", 0) == [self]
    assert Local.subscribers(config.pubsub, "topic6", 0) == []

    # Assert topic was also garbage collected
    assert Local.list(config.pubsub, 0) == ["topic5"]
  end

  test "subscriber is demonitored when it leaves the last topic", config do
    assert :ok = Local.subscribe(config.pubsub, @pool_size, self, "topic7")
    assert :ok = Local.subscribe(config.pubsub, @pool_size, self, "topic8")

    topics = Local.subscription(config.pubsub, @pool_size, self)
    assert Enum.sort(topics) == ["topic7", "topic8"]

    assert :ok = Local.unsubscribe(config.pubsub, @pool_size, self, "topic7")
    topics = Local.subscription(config.pubsub, @pool_size, self)
    assert Enum.sort(topics) == ["topic8"]

    :ok = Local.unsubscribe(config.pubsub, @pool_size, self, "topic8")
    assert Local.subscription(config.pubsub, @pool_size, self) == []
  end
end
