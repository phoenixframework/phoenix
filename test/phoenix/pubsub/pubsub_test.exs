defmodule Phoenix.PubSub.PubSubTest do
  use ExUnit.Case, async: true

  alias Phoenix.PubSub
  alias Phoenix.Socket.Broadcast
  alias Phoenix.Socket.Message
  alias Phoenix.Socket.Reply

  @pool_size 1

  setup_all do
    # TODO: Do not depend on Phoenix.Channel.Server
    {:ok, _} =
      Phoenix.PubSub.PG2.start_link(__MODULE__, [pool_size: @pool_size, fastlane: Phoenix.Channel.Server])
    :ok
  end

  setup do
    Process.register(self(), :phx_pubsub_test_subscriber)
    :ok
  end

  def broadcast(error, _, _, _, _) do
    {:error, error}
  end

  defmodule Serializer do
    @behaviour Phoenix.Transports.Serializer

    def fastlane!(%Broadcast{} = msg) do
      send(Process.whereis(:phx_pubsub_test_subscriber), {:fastlaned, msg})
      %Message{
        topic: msg.topic,
        event: msg.event,
        payload: msg.payload
      }
    end

    def encode!(%Reply{} = reply) do
      %Message{
        topic: reply.topic,
        event: "phx_reply",
        ref: reply.ref,
        payload: %{status: reply.status, response: reply.payload}
      }
    end
    def encode!(%Message{} = msg) do
      msg
    end

    def decode!(message, _opts), do: message
  end

  test "broadcast!/3 and broadcast_from!/4 raises if broadcast fails" do
    :ets.new(FailedBroadcaster, [:named_table])
    :ets.insert(FailedBroadcaster, {:broadcast, __MODULE__, [:boom]})

    {:error, :boom} = PubSub.broadcast(FailedBroadcaster, "hello", %{})

    assert_raise PubSub.BroadcastError, fn ->
      PubSub.broadcast!(FailedBroadcaster, "topic", :ping)
    end

    assert_raise PubSub.BroadcastError, fn ->
      PubSub.broadcast_from!(FailedBroadcaster, self, "topic", :ping)
    end
  end

  test "fastlaning skips subscriber and sends directly to fastlane pid" do
    some_subscriber = spawn_link fn -> :timer.sleep(:infinity) end
    fastlane_pid = spawn_link fn -> :timer.sleep(:infinity) end

    PubSub.subscribe(__MODULE__, some_subscriber, "topic1",
                     fastlane: {fastlane_pid, Serializer, ["intercepted"]})
    PubSub.subscribe(__MODULE__, self(), "topic1",
                     fastlane: {fastlane_pid, Serializer, ["intercepted"]})

    PubSub.broadcast(__MODULE__, "topic1", %Broadcast{event: "fastlaned", topic: "topic1", payload: %{}})

    fastlaned = %Message{event: "fastlaned", topic: "topic1", payload: %{}}
    refute_receive %Broadcast{}
    refute_receive %Message{}
    assert_receive {:fastlaned, %Broadcast{}}
    assert Process.info(fastlane_pid)[:messages] == [fastlaned, fastlaned]
    assert Process.info(self())[:messages] == [] # cached and fastlaned only sent once

    PubSub.broadcast(__MODULE__, "topic1", %Broadcast{event: "intercepted", topic: "topic1", payload: %{}})

    assert_receive %Broadcast{event: "intercepted", topic: "topic1", payload: %{}}
    assert Process.info(fastlane_pid)[:messages]
           == [fastlaned, fastlaned] # no additional messages received
  end
end
