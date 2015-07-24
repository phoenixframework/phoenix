defmodule Phoenix.PubSub.PubSubTest do
  use ExUnit.Case, async: true

  alias Phoenix.PubSub
  alias Phoenix.Socket.Broadcast
  alias Phoenix.Socket.Message
  alias Phoenix.Socket.Reply

  setup_all do
    {:ok, _} = Phoenix.PubSub.PG2.start_link(__MODULE__, [])
    :ok
  end

  def broadcast(error, _, _, _) do
    {:error, error}
  end

  defmodule Serializer do
    def encode!(%Reply{} = reply) do
      %Message{
        topic: reply.topic,
        event: "phx_reply",
        ref: reply.ref,
        payload: %{status: reply.status, response: reply.payload}
      }
    end
    def encode!(%Broadcast{} = msg) do
      send(self(), {:serialized, msg})
      %Message{
        topic: msg.topic,
        event: msg.event,
        payload: msg.payload
      }
    end
    def encode!(%Message{} = msg) do
      msg
    end

    def decode!(message, :text), do: message
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
    assert_receive {:serialized, %Broadcast{}}
    assert Process.info(fastlane_pid)[:messages] == [fastlaned, fastlaned]
    assert Process.info(self())[:messages] == [] # cached and serialized only sent once

    PubSub.broadcast(__MODULE__, "topic1", %Broadcast{event: "intercepted", topic: "topic1", payload: %{}})

    assert_receive %Broadcast{event: "intercepted", topic: "topic1", payload: %{}}
    assert Process.info(fastlane_pid)[:messages]
           == [fastlaned, fastlaned] # no additional messages received
  end
end
