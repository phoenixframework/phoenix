defmodule Phoenix.Channel.ChannelTest do
  use ExUnit.Case
  alias Phoenix.Topic
  alias Phoenix.Channel
  alias Phoenix.Socket

  def new_socket do
    %Socket{pid: self,
            router: nil,
            channel: "somechan",
            channels: [],
            assigns: []}
  end

  test "#subscribe/unsubscribe's socket to/from topic" do
    socket = Socket.set_current_channel(new_socket, "chan", "topic")

    assert Channel.subscribe(socket, "chan", "topic")
    assert Topic.subscribers("chan:topic") == [socket.pid]
    assert Channel.unsubscribe(socket, "chan", "topic")
    assert Topic.subscribers("chan:topic") == []
  end

  test "#broadcast broadcasts global message on channel" do
    Topic.create("chan:topic")
    socket = Socket.set_current_channel(new_socket, "chan", "topic")

    assert Channel.broadcast(socket, "event", foo: :bar)
  end

  test "#broadcast_from broadcasts message on channel from publisher" do
    Topic.create("chan:topic")
    socket = Socket.set_current_channel(new_socket, "chan", "topic")

    assert Channel.broadcast_from(socket, "event", :hello)
    _message = JSON.encode!(:hello)
    refute_received _message
  end

  test "#reply sends response to socket" do
    socket = Socket.set_current_channel(new_socket, "chan", "topic")
    assert Channel.reply(socket, "event", :hello)
    _message = JSON.encode!(:hello)
    assert_received _message
  end

  test "Default #leave is generated as a noop" do
    defmodule Chan1 do
      use Phoenix.Channel
    end

    assert Chan1.leave(new_socket) == :noop
  end

  test "#leave can be overridden" do
    defmodule Chan2 do
      use Phoenix.Channel
      def leave(socket), do: :overridden
    end

    assert Chan2.leave(new_socket) == :overridden
  end
end

