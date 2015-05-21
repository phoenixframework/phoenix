defmodule Phoenix.PubSub.PubSubTest do
  use ExUnit.Case, async: true

  alias Phoenix.PubSub
  alias Phoenix.PubSub.Local

  def spawn_pid do
    {:ok, pid} = Task.start(fn -> :timer.sleep(:infinity) end)
    pid
  end

  defp kill_and_wait(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, _, _, _}
  end

  defmodule FailedBroadcaster do
    use GenServer

    def handle_call(_msg, _from, state) do
      {:reply, {:error, :boom}, state}
    end
  end

  test "broadcast!/3 and broadcast_from!/4 raises if broadcast fails" do
    GenServer.start_link(FailedBroadcaster, :ok, name: FailedBroadcaster)

    assert_raise PubSub.BroadcastError, fn ->
      PubSub.broadcast!(FailedBroadcaster, "topic", :ping)
    end

    assert_raise PubSub.BroadcastError, fn ->
      PubSub.broadcast_from!(FailedBroadcaster, self, "topic", :ping)
    end
  end

  setup config do
    {:ok, _} = Phoenix.PubSub.PG2.start_link(config.test, [])
    {:ok, local: Module.concat(config.test, Elixir.Local)}
  end

  test "subscribe and unsubscribe", config do
    pid = spawn_pid
    assert Local.subscribers(config.local, "topic4") == []
    assert PubSub.subscribe(config.test, pid, "topic4")
    assert Local.subscribers(config.local, "topic4") == [pid]
    assert PubSub.unsubscribe(config.test, pid, "topic4")
    assert Local.subscribers(config.local, "topic4") == []
  end

  test "subscribe/3 with link does not down adapter", config do
    pid   = spawn_pid()
    local = Process.whereis(config.local)
    assert PubSub.subscribe(config.test, pid, "topic4", link: true)

    kill_and_wait(pid)
    assert Process.alive?(local)
    assert Local.subscribers(config.local, "topic4") == []
  end

  test "subscribe/3 with link downs subscriber", config do
    pid = spawn_pid
    non_linked_pid1 = spawn_pid
    non_linked_pid2 = spawn_pid

    assert PubSub.subscribe(config.test, pid, "topic4", link: true)
    assert PubSub.subscribe(config.test, non_linked_pid1, "topic4")
    assert PubSub.subscribe(config.test, non_linked_pid2, "topic4", link: false)

    kill_and_wait(Process.whereis(config.local))

    refute Process.alive?(pid)
    assert Process.alive?(non_linked_pid1)
    assert Process.alive?(non_linked_pid2)
  end

  test "broadcast/3 and broadcast!/3 publishes message to each subscriber", config do
    PubSub.subscribe(config.test, self, "topic9")
    :ok = PubSub.broadcast(config.test, "topic9", :ping)
    assert_receive :ping
    :ok = PubSub.broadcast!(config.test, "topic9", :ping)
    assert_receive :ping
  end

  test "broadcast/3 does not publish message to other topic subscribers", config do
    PubSub.subscribe(config.test, self, "topic9")

    Enum.each 0..10, fn _ ->
      PubSub.subscribe(config.test, spawn_pid(), "topic10")
    end

    :ok = PubSub.broadcast(config.test, "topic10", :ping)
    refute_received :ping
  end

  test "broadcast_from/4 and broadcast_from!/4 skips sender", config do
    PubSub.subscribe(config.test, self, "topic11")

    PubSub.broadcast_from(config.test, self, "topic11", :ping)
    refute_received :ping

    PubSub.broadcast_from!(config.test, self, "topic11", :ping)
    refute_received :ping
  end
end
