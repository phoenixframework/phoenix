defmodule Phoenix.Channel.ChannelTest do
  use ExUnit.Case, async: true

  @pubsub __MODULE__.PubSub
  import Phoenix.Channel

  defmodule ClusterAdapter do
    # Sends what would be broadcast to other nodes to the test process
    @behaviour Phoenix.PubSub.Adapter

    def node_name(_adapter_name), do: node()

    def child_spec(opts) do
      test_pid = Keyword.fetch!(opts, :test_pid)
      agent_opts = [name: opts[:adapter_name]]
      %{id: __MODULE__, start: {Agent, :start_link, [fn -> test_pid end, agent_opts]}}
    end

    def broadcast(adapter_name, topic, message, dispatcher) do
      send(Agent.get(adapter_name, & &1), {:cluster_broadcast, topic, message, dispatcher})
      :ok
    end

    def direct_broadcast(adapter_name, _node_name, topic, message, dispatcher) do
      broadcast(adapter_name, topic, message, dispatcher)
    end
  end

  setup_all do
    start_supervised! {Phoenix.PubSub, name: @pubsub, pool_size: 1}
    :ok
  end

  test "broadcasts from self" do
    Phoenix.PubSub.subscribe(@pubsub, "sometopic")

    socket = %Phoenix.Socket{
      pubsub_server: @pubsub,
      topic: "sometopic",
      channel_pid: self(),
      joined: true
    }

    broadcast_from(socket, "event1", %{key: :val})

    refute_received %Phoenix.Socket.Broadcast{
      event: "event1",
      payload: %{key: :val},
      topic: "sometopic"
    }

    broadcast_from!(socket, "event2", %{key: :val})

    refute_received %Phoenix.Socket.Broadcast{
      event: "event2",
      payload: %{key: :val},
      topic: "sometopic"
    }

    broadcast(socket, "event3", %{key: :val})

    assert_receive %Phoenix.Socket.Broadcast{
      event: "event3",
      payload: %{key: :val},
      topic: "sometopic"
    }

    broadcast!(socket, "event4", %{key: :val})

    assert_receive %Phoenix.Socket.Broadcast{
      event: "event4",
      payload: %{key: :val},
      topic: "sometopic"
    }
  end

  test "broadcasts from other" do
    Phoenix.PubSub.subscribe(@pubsub, "sometopic")

    socket = %Phoenix.Socket{
      pubsub_server: @pubsub,
      topic: "sometopic",
      channel_pid: spawn_link(fn -> :ok end),
      joined: true
    }

    broadcast_from(socket, "event1", %{key: :val})

    assert_receive %Phoenix.Socket.Broadcast{
      event: "event1",
      payload: %{key: :val},
      topic: "sometopic"
    }

    broadcast_from!(socket, "event2", %{key: :val})

    assert_receive %Phoenix.Socket.Broadcast{
      event: "event2",
      payload: %{key: :val},
      topic: "sometopic"
    }

    broadcast(socket, "event3", %{key: :val})

    assert_receive %Phoenix.Socket.Broadcast{
      event: "event3",
      payload: %{key: :val},
      topic: "sometopic"
    }

    broadcast!(socket, "event4", %{key: :val})

    assert_receive %Phoenix.Socket.Broadcast{
      event: "event4",
      payload: %{key: :val},
      topic: "sometopic"
    }
  end

  # TODO: Remove in Phoenix 1.10
  test "broadcasts to other nodes with Phoenix.Channel.Server as dispatcher" do
    pubsub = __MODULE__.ClusterPubSub
    start_supervised!({Phoenix.PubSub, name: pubsub, adapter: ClusterAdapter, test_pid: self()})

    socket = %Phoenix.Socket{
      pubsub_server: pubsub,
      topic: "sometopic",
      channel_pid: spawn_link(fn -> :ok end),
      joined: true
    }

    broadcast(socket, "event1", %{key: :val})

    assert_receive {:cluster_broadcast, "sometopic", %Phoenix.Socket.Broadcast{event: "event1"},
                    Phoenix.Channel.Server}

    broadcast!(socket, "event2", %{key: :val})

    assert_receive {:cluster_broadcast, "sometopic", %Phoenix.Socket.Broadcast{event: "event2"},
                    Phoenix.Channel.Server}

    broadcast_from(socket, "event3", %{key: :val})

    assert_receive {:cluster_broadcast, "sometopic", %Phoenix.Socket.Broadcast{event: "event3"},
                    Phoenix.Channel.Server}

    broadcast_from!(socket, "event4", %{key: :val})

    assert_receive {:cluster_broadcast, "sometopic", %Phoenix.Socket.Broadcast{event: "event4"},
                    Phoenix.Channel.Server}
  end

  test "pushing to transport" do
    socket = %Phoenix.Socket{
      serializer: Phoenix.ChannelTest.NoopSerializer,
      topic: "sometopic",
      transport_pid: self(),
      joined: true
    }

    push(socket, "event1", %{key: :val})

    assert_receive %Phoenix.Socket.Message{
      event: "event1",
      payload: %{key: :val},
      topic: "sometopic"
    }
  end

  test "replying to transport" do
    socket = %Phoenix.Socket{
      serializer: Phoenix.ChannelTest.NoopSerializer,
      ref: "123",
      topic: "sometopic",
      transport_pid: self(),
      joined: true
    }

    ref = socket_ref(socket)
    reply(ref, {:ok, %{key: :val}})

    assert_receive %Phoenix.Socket.Reply{
      payload: %{key: :val},
      ref: "123",
      status: :ok,
      topic: "sometopic"
    }
  end

  test "replying just status to transport" do
    socket = %Phoenix.Socket{
      serializer: Phoenix.ChannelTest.NoopSerializer,
      ref: "123",
      topic: "sometopic",
      transport_pid: self(),
      joined: true
    }

    ref = socket_ref(socket)
    reply(ref, :ok)

    assert_receive %Phoenix.Socket.Reply{
      payload: %{},
      ref: "123",
      status: :ok,
      topic: "sometopic"
    }
  end

  test "socket_ref raises ArgumentError when socket is not joined or has no ref" do
    assert_raise ArgumentError, ~r"join", fn ->
      socket_ref(%Phoenix.Socket{joined: false})
    end

    assert_raise ArgumentError, ~r"ref", fn ->
      socket_ref(%Phoenix.Socket{joined: true})
    end
  end
end
