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
    start_supervised!({Phoenix.PubSub, name: @pubsub, pool_size: 1})
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

  test "broadcasts to other nodes with the default dispatcher" do
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
                    Phoenix.PubSub}

    broadcast!(socket, "event2", %{key: :val})

    assert_receive {:cluster_broadcast, "sometopic", %Phoenix.Socket.Broadcast{event: "event2"},
                    Phoenix.PubSub}

    broadcast_from(socket, "event3", %{key: :val})

    assert_receive {:cluster_broadcast, "sometopic", %Phoenix.Socket.Broadcast{event: "event3"},
                    Phoenix.PubSub}

    broadcast_from!(socket, "event4", %{key: :val})

    assert_receive {:cluster_broadcast, "sometopic", %Phoenix.Socket.Broadcast{event: "event4"},
                    Phoenix.PubSub}
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

  test "fastlane errors are logged and stop only channels using that serializer" do
    topic = "fastlane:#{System.unique_integer()}"

    # The V1 subscribers come first, so their serializer raises before
    # the V2 subscriber is dispatched (single partition, insertion order).
    v1_transport = forwarder(:v1_transport)

    _v1_channel =
      forwarder(:v1_channel, subscriber(topic, v1_transport, Phoenix.Socket.V1.JSONSerializer))

    v1_transport_2 = forwarder(:v1_transport_2)

    _v1_channel_2 =
      forwarder(
        :v1_channel_2,
        subscriber(topic, v1_transport_2, Phoenix.Socket.V1.JSONSerializer)
      )

    v2_transport = forwarder(:v2_transport)

    _v2_channel =
      forwarder(:v2_channel, subscriber(topic, v2_transport, Phoenix.Socket.V2.JSONSerializer))

    msg = %Phoenix.Socket.Broadcast{topic: topic, event: "evt", payload: {:binary, <<1, 2, 3>>}}

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        assert :ok = Phoenix.PubSub.broadcast(@pubsub, topic, msg)
      end)

    assert_receive {:v2_transport, {:socket_push, :binary, <<2, _::binary>>}}
    assert_receive {:v1_channel, {Phoenix.Channel.Server, :fastlane_error}}
    assert_receive {:v1_channel_2, {Phoenix.Channel.Server, :fastlane_error}}
    refute_received {:v1_transport, _}
    refute_received {:v1_transport_2, _}

    # logged once for both V1 subscribers, as the failure is cached per serializer
    stopping =
      "Stopping channels on topic #{inspect(topic)} that use Phoenix.Socket.V1.JSONSerializer"

    assert [_, _] = String.split(log, stopping)
    assert log =~ "unable to send a binary payload"
  end

  defp subscriber(topic, transport_pid, serializer) do
    sender = {Phoenix.Channel.Server, {transport_pid, serializer, []}}
    fn -> Phoenix.PubSub.subscribe(@pubsub, topic, sender: sender) end
  end

  # Starts a process that runs `setup` and then forwards
  # every message it receives to the test process as `{tag, msg}`.
  defp forwarder(tag, setup \\ fn -> :ok end) do
    test_pid = self()

    pid =
      spawn_link(fn ->
        setup.()
        send(test_pid, {:ready, self()})
        forward(test_pid, tag)
      end)

    assert_receive {:ready, ^pid}
    pid
  end

  defp forward(test_pid, tag) do
    receive do
      msg ->
        send(test_pid, {tag, msg})
        forward(test_pid, tag)
    end
  end
end
