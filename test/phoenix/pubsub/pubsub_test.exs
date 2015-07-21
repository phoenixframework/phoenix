defmodule Phoenix.PubSub.PubSubTest do
  use ExUnit.Case, async: true

  alias Phoenix.PubSub

  def broadcast(error, _, _, _) do
    {:error, error}
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
end
