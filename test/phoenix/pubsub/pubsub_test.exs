defmodule Phoenix.PubSub.PubSubTest do
  use ExUnit.Case, async: true

  alias Phoenix.PubSub

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
end
