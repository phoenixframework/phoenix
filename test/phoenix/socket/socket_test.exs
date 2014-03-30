defmodule Phoenix.Socket.SocketTest do
  use ExUnit.Case
  alias Phoenix.Socket

  def new_socket do
    %Socket{pid: self,
            router: nil,
            channels: [],
            assigns: []}
  end

  test "#set_current_channel sets the current channel" do
    socket = new_socket |> Socket.set_current_channel("somechan")
    assert socket.channel == "somechan"
  end

  test "#authenticated? returns true if socket belongs to channel" do
    socket = new_socket
    socket = Socket.add_channel(socket, "topic")
    assert Socket.authenticated?(socket, "topic")
  end

  test "#authenticated? returns false if socket does not belong to channel" do
    socket = new_socket
    refute Socket.authenticated?(socket, "topic")
  end

  test "#add_channel adds channel" do
    socket = new_socket |> Socket.add_channel("test")
    assert socket.channels == ["test"]
  end

  test "#delete_channel deletes channel" do
    socket = new_socket |> Socket.add_channel("test")
    assert socket.channels == ["test"]
    socket = Socket.delete_channel(socket, "test")
    assert socket.channels == []
  end
end

