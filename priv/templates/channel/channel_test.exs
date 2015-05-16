defmodule <%= module %>ChannelTest do
  use <%= base %>.ChannelCase

  alias <%= module %>

  test "successful join of <%= plural %>:lobby" do
    assert {:ok, _, socket} = join(<%= scoped %>Channel, "<%= plural %>:lobby")
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
