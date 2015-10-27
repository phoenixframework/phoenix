defmodule Phoenix.LocalTest do
  use ExUnit.Case, async: true

  alias Phoenix.PubSub.Local

  @pool_size 1

  setup config do
    local = :"#{config.test}_local"
    pool1 = :"#{local}0"
    ^local = :ets.new(local, [:bag, :named_table, :public, read_concurrency: true])
    true = :ets.insert(local, {0, pool1})
    {:ok, _} = Local.start_link(pool1)
    {:ok, local: local}
  end

  test "subscribe/2 joins a pid to a topic and broadcast/2 sends messages", config do
    # subscribe
    pid = spawn fn -> :timer.sleep(:infinity) end
    assert Local.subscribers(config.local, "foo", 0) == []
    assert :ok = Local.subscribe(config.local, @pool_size, self, "foo")
    assert :ok = Local.subscribe(config.local, @pool_size, pid, "foo")
    assert :ok = Local.subscribe(config.local, @pool_size, self, "bar")

    # broadcast
    assert :ok = Local.broadcast(config.local, :none, @pool_size, "foo", :hellofoo)
    assert_received :hellofoo
    assert Process.info(pid)[:messages] == [:hellofoo]

    assert :ok = Local.broadcast(config.local, :none, @pool_size, "bar", :hellobar)
    assert_received :hellobar
    assert Process.info(pid)[:messages] == [:hellofoo]

    assert :ok = Local.broadcast(config.local, :none, @pool_size, "unknown", :hellobar)
    assert Process.info(self)[:messages] == []
  end

  test "unsubscribe/2 leaves group", config do
    pid = spawn fn -> :timer.sleep(:infinity) end
    assert :ok = Local.subscribe(config.local, @pool_size, self, "topic1")
    assert :ok = Local.subscribe(config.local, @pool_size, pid, "topic1")

    assert Local.subscribers(config.local, "topic1", 0) == [self, pid]
    assert :ok = Local.unsubscribe(config.local, @pool_size, self, "topic1")
    assert Local.subscribers(config.local, "topic1", 0) == [pid]
  end

  test "unsubscribe/2 gargabes collect topic when there are no more subscribers", config do
    assert :ok = Local.subscribe(config.local, @pool_size, self, "topic1")

    assert Local.list(config.local, 0) == ["topic1"]
    assert Local.unsubscribe(config.local, @pool_size, self, "topic1")

    assert Enum.count(Local.list(config.local, 0)) == 0
    assert Enum.count(Local.subscribers(config.local, "topic1", 0)) == 0
  end

  test "unsubscribe/2 when topic does not exists", config do
    assert :ok = Local.unsubscribe(config.local, @pool_size, self, "notexists")
    assert Enum.count(Local.subscribers(config.local, "notexists", 0)) == 0
  end

  test "pid is removed when DOWN", config do
    {pid, ref} = spawn_monitor fn -> :timer.sleep(:infinity) end
    assert :ok = Local.subscribe(config.local, @pool_size, self, "topic5")
    assert :ok = Local.subscribe(config.local, @pool_size, pid, "topic5")
    assert :ok = Local.subscribe(config.local, @pool_size, pid, "topic6")

    Process.exit(pid,  :kill)
    assert_receive {:DOWN, ^ref, _, _, _}

    # Ensure DOWN is processed to avoid races
    Local.unsubscribe(config.local, @pool_size, pid, "unknown")

    assert Local.subscription(config.local, @pool_size, pid) == []
    assert Local.subscribers(config.local, "topic5", 0) == [self]
    assert Local.subscribers(config.local, "topic6", 0) == []

    # Assert topic was also garbage collected
    assert Local.list(config.local, 0) == ["topic5"]
  end

  test "subscriber is demonitored when it leaves the last topic", config do
    assert :ok = Local.subscribe(config.local, @pool_size, self, "topic7")
    assert :ok = Local.subscribe(config.local, @pool_size, self, "topic8")

    topics = Local.subscription(config.local, @pool_size, self)
    assert Enum.sort(topics) == ["topic7", "topic8"]

    assert :ok = Local.unsubscribe(config.local, @pool_size, self, "topic7")
    topics = Local.subscription(config.local, @pool_size, self)
    assert Enum.sort(topics) == ["topic8"]

    :ok = Local.unsubscribe(config.local, @pool_size, self, "topic8")
    assert Local.subscription(config.local, @pool_size, self) == []
  end
end
