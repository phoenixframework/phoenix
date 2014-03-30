defmodule Phoenix.Channel.ChannelTest do
  use ExUnit.Case
  alias Phoenix.Topic
  alias Phoenix.Channel
  alias Phoenix.Socket
  alias Phoenix.Socket.Handler

  def new_socket do
    %Socket{pid: self,
            router: nil,
            channels: [],
            assigns: []}
  end

  test "#subscribe subscribes socket to topic" do
    socket = new_socket

    assert Channel.subscribe(socket, "somechan", "topic")
    assert Topic.subscribers("somechan:topic") == [socket.pid]
  end

  test "#broadcast broadcasts global message on channel" do
    Topic.create("somechan:topic")
    assert Channel.broadcast("somechan", "topic", foo: :bar)
  end

  test "#broadcast_from broadcasts message on channel from publisher" do
    Topic.create("somechan:topic")
    assert Channel.broadcast_from(new_socket, "somechan", "topic", :hello)
    message = JSON.encode!(:hello)
    refute_received message
  end

  test "#reply sends response to socket" do
    socket = new_socket
    assert Channel.reply(socket, :hello)
    message = JSON.encode!(:hello)
    assert_received message
  end
end

