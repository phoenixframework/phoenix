defmodule <%= module %>ChannelTest do
  use ExUnit.Case
  alias <%= module %>

  @endpoint <%= base %>.Endpoint
  use Phoenix.ChannelTest

  setup_all do
    @endpoint.start_link()
    :ok
  end

  test "successful join of <%= plural %>:lobby" do
    assert {:ok, socket, _} = join(<%= scoped %>Channel, "<%= plural %>:lobby")
    assert socket.topic == "<%= plural %>:lobby"
  end

  test "ping replies with pong" do
    {:ok, _, socket} = join(<%= scoped %>Channel, "<%= plural %>:lobby")

    ref = push socket, "ping", %{"hello" => "there"}
    assert_reply ref, :pong, %{"hello" => "there"}
  end

  test "shout broadcasts to <%= plural %>:lobby" do
    {:ok, _, socket} = subscribe_and_join(<%= scoped %>Channel, "<%= plural %>:lobby")

    push socket, "broadcast", %{"foo" => "bar"}
    assert_broadcast "broadcast", %{"foo" => "bar"}
  end
end
