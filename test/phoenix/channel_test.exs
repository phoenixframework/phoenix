defmodule Phoenix.Channel.ChannelTest do
  use ExUnit.Case, async: true

  @pubsub __MODULE__.PubSub
  import Phoenix.Channel

  setup_all do
    {:ok, _} = Phoenix.PubSub.PG2.start_link(@pubsub, pool_size: 1)
    :ok
  end

  test "broadcasts from self" do
    Phoenix.PubSub.subscribe(@pubsub, "sometopic")

    socket = %Phoenix.Socket{pubsub_server: @pubsub, topic: "sometopic",
                             channel_pid: self(), joined: true}

    broadcast_from(socket, "event1", %{key: :val})
    refute_received %Phoenix.Socket.Broadcast{
      event: "event1", payload: %{key: :val}, topic: "sometopic"}

    broadcast_from!(socket, "event2", %{key: :val})
    refute_received %Phoenix.Socket.Broadcast{
      event: "event2", payload: %{key: :val}, topic: "sometopic"}

    broadcast(socket, "event3", %{key: :val})
    assert_receive %Phoenix.Socket.Broadcast{
      event: "event3", payload: %{key: :val}, topic: "sometopic"}

    broadcast!(socket, "event4", %{key: :val})
    assert_receive %Phoenix.Socket.Broadcast{
      event: "event4", payload: %{key: :val}, topic: "sometopic"}
  end

  test "broadcasts from other" do
    Phoenix.PubSub.subscribe(@pubsub, "sometopic")

    socket = %Phoenix.Socket{pubsub_server: @pubsub, topic: "sometopic",
                             channel_pid: spawn_link(fn -> :ok end), joined: true}

    broadcast_from(socket, "event1", %{key: :val})
    assert_receive %Phoenix.Socket.Broadcast{
      event: "event1", payload: %{key: :val}, topic: "sometopic"}

    broadcast_from!(socket, "event2", %{key: :val})
    assert_receive %Phoenix.Socket.Broadcast{
      event: "event2", payload: %{key: :val}, topic: "sometopic"}

    broadcast(socket, "event3", %{key: :val})
    assert_receive %Phoenix.Socket.Broadcast{
      event: "event3", payload: %{key: :val}, topic: "sometopic"}

    broadcast!(socket, "event4", %{key: :val})
    assert_receive %Phoenix.Socket.Broadcast{
      event: "event4", payload: %{key: :val}, topic: "sometopic"}
  end

  test "broadcasts when not joined" do
    socket = %Phoenix.Socket{joined: false}

    assert_raise RuntimeError, ~r"join", fn ->
      broadcast_from(socket, "event", %{key: :val})
    end

    assert_raise RuntimeError, ~r"join", fn ->
      broadcast_from!(socket, "event", %{key: :val})
    end

    assert_raise RuntimeError, ~r"join", fn ->
      broadcast(socket, "event", %{key: :val})
    end

    assert_raise RuntimeError, ~r"join", fn ->
      broadcast!(socket, "event", %{key: :val})
    end
  end

  test "pushing to transport" do
    socket = %Phoenix.Socket{serializer: Phoenix.ChannelTest.NoopSerializer,
                             topic: "sometopic", transport_pid: self(), joined: true}
    push(socket, "event1", %{key: :val})
    assert_receive %Phoenix.Socket.Message{
      event: "event1", payload: %{key: :val}, topic: "sometopic"}
  end

  test "pushing when not joined" do
    socket = %Phoenix.Socket{joined: false}

    assert_raise RuntimeError, ~r"join", fn ->
      push(socket, "event", %{key: :val})
    end
  end

  test "replying to transport" do
    socket = %Phoenix.Socket{serializer: Phoenix.ChannelTest.NoopSerializer, ref: "123",
                             topic: "sometopic", transport_pid: self(), joined: true,}
    ref = socket_ref(socket)
    reply(ref, {:ok, %{key: :val}})
    assert_receive %Phoenix.Socket.Reply{
      payload: %{key: :val}, ref: "123", status: :ok, topic: "sometopic"}
  end

  test "replying just status to transport" do
    socket = %Phoenix.Socket{serializer: Phoenix.ChannelTest.NoopSerializer, ref: "123",
                             topic: "sometopic", transport_pid: self(), joined: true,}
    ref = socket_ref(socket)
    reply(ref, :ok)
    assert_receive %Phoenix.Socket.Reply{
      payload: %{}, ref: "123", status: :ok, topic: "sometopic"}
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
