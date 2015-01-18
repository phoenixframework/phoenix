defmodule Phoenix.SocketTest do
  # TODO: Should be async
  use ExUnit.Case
  alias Phoenix.Socket
  doctest Socket

  def new_socket do
    %Socket{pid: self}
  end

  test "put_topic/2 sets the topic" do
    socket = new_socket |> Socket.put_topic("sometopic:somesubtopic")
    assert socket.topic == "sometopic:somesubtopic"
  end

  test "put_channel/2 sets the channel" do
    socket = new_socket |> Socket.put_channel(MyChannel)
    assert socket.channel == MyChannel
  end

  test "authorized?/2 returns true if socket belongs to topic" do
    socket = new_socket
    socket = Socket.authorize(socket, "topic:subtopic")
    assert Socket.authorized?(socket, "topic:subtopic")
    refute Socket.authorized?(socket, "topic:othertopic")
  end

  test "authorized?/3 returns false if socket does not belong to topic" do
    socket = new_socket
    refute Socket.authorized?(socket, "sometopic:subtopic")
  end

  test "deauthorize/1 deletes topic" do
    socket = new_socket |> Socket.authorize("test:topic")
    assert Socket.authorized?(socket, "test:topic")
    socket = Socket.deauthorize(socket)
    refute Socket.authorized?(socket, "test:topic")
  end

  test "socket assigns can be accessed from assigns map" do
    socket = new_socket |> Socket.assign(:key, :val)
    assert socket.assigns[:key] == :val
  end
end
