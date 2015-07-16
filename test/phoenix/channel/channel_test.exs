defmodule Phoenix.Channel.ChannelTest do
  use ExUnit.Case, async: true

  @pubsub __MODULE__.PubSub
  import Phoenix.Channel

  setup_all do
    {:ok, _} = Phoenix.PubSub.PG2.start_link(@pubsub, [])
    :ok
  end

  test "broadcasts from self" do
    Phoenix.PubSub.subscribe(@pubsub, self, "sometopic")

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
    Phoenix.PubSub.subscribe(@pubsub, self, "sometopic")

    socket = %Phoenix.Socket{pubsub_server: @pubsub, topic: "sometopic",
                             channel_pid: spawn_link(fn -> end), joined: true}

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
    socket = %Phoenix.Socket{topic: "sometopic", transport_pid: self(), joined: true}
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
end
