defmodule Phoenix.PubSub.PubSubTest do
  use ExUnit.Case, async: true

  alias Phoenix.PubSub
  alias Phoenix.PubSub.Local

  @adapters [redis: Phoenix.PubSub.Redis,
             pg2: Phoenix.PubSub.PG2]

  def spawn_pid do
    {:ok, pid} = Task.start_link(fn -> :timer.sleep(:infinity) end)
    pid
  end

  defmodule FailedBroadcaster do
    def broadcast(_server, _topic, _msg), do: {:error, :boom}
    def broadcast_from(_server, _from_pid, _topic, _msg), do: {:error, :boom}
  end

  for {tag, adapter} <- @adapters do
    @key tag
    @name adapter
    @local Module.concat(adapter, Elixir.Local)
    @adapter adapter

    setup meta do
      if meta[@key] do
        {:ok, pid} = @adapter.start_link(@name, [])

        on_exit fn ->
          ref = Process.monitor(pid)
          assert_receive {:DOWN, ^ref, :process, ^pid, _}
        end
      end

      :ok
    end

    @tag tag
    test "#{inspect @adapter} subscribe and unsubscribe" do
      pid = spawn_pid
      assert Local.subscribers(@local, "topic4") == []
      assert PubSub.subscribe(@name, pid, "topic4")
      assert Local.subscribers(@local, "topic4") == [pid]
      assert PubSub.unsubscribe(@name, pid, "topic4")
      assert Local.subscribers(@local, "topic4") == []
    end

    @tag tag
    test "#{inspect @adapter} subscribe/3 with link does not down adapter" do
      Process.flag(:trap_exit, true)

      pid   = spawn_pid
      local = Process.whereis(@local)

      assert PubSub.subscribe(@name, pid, "topic4", link: true)
      Process.exit(pid, :kill)

      refute Process.alive?(pid)
      assert Process.alive?(local)
    end

    @tag tag
    test "#{inspect @adapter} subscribe/3 with link downs subscriber" do
      Process.flag(:trap_exit, true)

      pid = spawn_pid
      non_linked_pid1 = spawn_pid
      non_linked_pid2 = spawn_pid

      assert PubSub.subscribe(@name, pid, "topic4", link: true)
      assert PubSub.subscribe(@name, non_linked_pid1, "topic4")
      assert PubSub.subscribe(@name, non_linked_pid2, "topic4", link: false)

      Process.exit(Process.whereis(@local), :kill)
      Logger.flush()

      refute Process.alive?(pid)
      assert Process.alive?(non_linked_pid1)
      assert Process.alive?(non_linked_pid2)
    end

    @tag tag
    test "#{inspect @adapter} broadcast/3 and broadcast!/3 publishes message to each subscriber" do
      PubSub.subscribe(@name, self, "topic9")
      :ok = PubSub.broadcast(@name, "topic9", :ping)
      assert_receive :ping
      :ok = PubSub.broadcast!(@name, "topic9", :ping)
      assert_receive :ping
    end

    @tag tag
    test "#{inspect @adapter} broadcast!/3 and broadcast_from!/4 raise if broadcast fails" do
      PubSub.subscribe(@name, self, "topic9")

      assert_raise PubSub.BroadcastError, fn ->
        PubSub.broadcast!(@name, "topic9", :ping, FailedBroadcaster)
      end

      assert_raise PubSub.BroadcastError, fn ->
        PubSub.broadcast_from!(@name, self, "topic9", :ping, FailedBroadcaster)
      end

      refute_received :ping
    end

    @tag tag
    test "#{inspect @adapter} broadcast/3 does not publish message to other topic subscribers" do
      PubSub.subscribe(@name, self, "topic9")

      Enum.each 0..10, fn _ ->
        PubSub.subscribe(@name, spawn_pid, "topic10")
      end

      :ok = PubSub.broadcast(@name, "topic10", :ping)
      refute_received :ping
    end

    @tag tag
    test "#{inspect @adapter} broadcast_from/4 and broadcast_from!/4 skips sender" do
      PubSub.subscribe(@name, self, "topic11")

      PubSub.broadcast_from(@name, self, "topic11", :ping)
      refute_received :ping

      PubSub.broadcast_from!(@name, self, "topic11", :ping)
      refute_received :ping
    end

    @tag tag
    test "#{inspect @adapter} processes automatically removed from topic when killed" do
      Process.flag(:trap_exit, true)

      pid = spawn_pid
      assert PubSub.subscribe(@name, pid, "topic12")

      ref = Process.monitor pid
      Process.exit pid, :kill
      assert_receive {:DOWN, ^ref, :process, ^pid, _}

      assert Local.subscribers(@local, "topic12") == []
    end
  end
end
