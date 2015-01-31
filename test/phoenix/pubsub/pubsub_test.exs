defmodule Phoenix.PubSub.PubSubTest do
  # TODO: Should be async
  use ExUnit.Case
  alias Phoenix.PubSub

  @adapters [
    {Phoenix.PubSub.Redis, :redis_pub},
    {Phoenix.PubSub.PG2,   :pg2_pub}
  ]

  def spawn_pid do
    spawn fn -> :timer.sleep(:infinity) end
  end

  for {adapter, name} <- @adapters do
    @adapter adapter
    @server name
    setup_all do
      @adapter.start_link(@server)
      :ok
    end

    test "#{inspect @adapter} #subscribers, #subscribe, #unsubscribe" do
      pid = spawn_pid
      assert Enum.empty?(PubSub.subscribers(@server, "topic4"))
      assert PubSub.subscribe(@server, pid, "topic4")
      assert PubSub.subscribers(@server, "topic4") |> Enum.to_list == [pid]
      assert PubSub.unsubscribe(@server, pid, "topic4")
      assert Enum.empty?(PubSub.subscribers(@server, "topic4"))
      Process.exit pid, :kill
    end

    test "#{inspect @adapter} subscribe/3 with link does not down adapter" do
      server_name = Module.concat(@server, :link_pub)
      {:ok, _super_pid} = @adapter.start_link(server_name)
      local_pid = Process.whereis(Module.concat(server_name, Local))
      assert Process.alive?(local_pid)
      pid = spawn_pid

      assert Enum.empty?(PubSub.subscribers(server_name, "topic4"))
      assert PubSub.subscribe(server_name, pid, "topic4", link: true)
      Process.exit(pid, :kill)
      refute Process.alive?(pid)
      assert Process.alive?(local_pid)
    end

    test "#{inspect @adapter} subscribe/3 with link downs subscriber" do
      server_name = Module.concat(@server, :link_pub2)
      {:ok, _super_pid} = @adapter.start_link(server_name)
      local_pid = Process.whereis(Module.concat(server_name, Local))
      assert Process.alive?(local_pid)
      pid = spawn_pid
      non_linked_pid = spawn_pid
      non_linked_pid2 = spawn_pid

      assert PubSub.subscribe(server_name, pid, "topic4", link: true)
      assert PubSub.subscribe(server_name, non_linked_pid, "topic4")
      assert PubSub.subscribe(server_name, non_linked_pid2, "topic4", link: false)
      Process.exit(local_pid, :kill)
      refute Process.alive?(local_pid)
      refute Process.alive?(pid)
      assert Process.alive?(non_linked_pid)
      assert Process.alive?(non_linked_pid2)
    end

    test "#{inspect @adapter} #broadcast publishes message to each subscriber" do
      PubSub.subscribe(@server, self, "topic9")
      assert PubSub.subscribers(@server, "topic9") |> Enum.to_list == [self]
      PubSub.broadcast(@server, "topic9", :ping)
      assert_receive :ping
    end

    test "#{inspect @adapter} #broadcast does not publish message to other topic subscribers" do
      pids = Enum.map 0..10, fn _ -> spawn_pid end
      pids |> Enum.each(&PubSub.subscribe(@server, &1, "topic10"))
      PubSub.broadcast(@server, "topic10", :ping)
      refute_receive :ping
      pids |> Enum.each(&Process.exit &1, :kill)
    end

    test "#{inspect @adapter} #broadcast_from does not publish to broadcaster pid when provided" do
      PubSub.subscribe(@server, self, "topic11")
      PubSub.broadcast_from(@server, self, "topic11", :ping)
      refute_receive :ping
    end

    test "#{inspect @adapter} processes automatically removed from topic when killed" do
      pid = spawn_pid
      assert PubSub.subscribe(@server, pid, "topic12")
      assert PubSub.subscribers(@server, "topic12") |> Enum.to_list == [pid]
      Process.exit pid, :kill
      :timer.sleep 10 # wait until adapter removes dead pid
      assert PubSub.subscribers(@server, "topic12") |> Enum.to_list == []
    end
  end
end
