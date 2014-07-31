defmodule Phoenix.Socket.SocketTest do
  use ExUnit.Case
  alias Phoenix.Socket
  doctest Socket

  def new_socket do
    %Socket{pid: self}
  end

  test "set_current_channel/3 sets the current channel" do
    socket = new_socket |> Socket.set_current_channel("somechan", "sometopic")
    assert socket.channel == "somechan"
    assert socket.topic == "sometopic"
  end

  test "authenticated?/3 returns true if socket belongs to channel scoped to topic" do
    socket = new_socket
    socket = Socket.add_channel(socket, "channel", "topic")
    assert Socket.authenticated?(socket, "channel", "topic")
    refute Socket.authenticated?(socket, "channel", "othertopic")
  end

  test "authenticated?/3 returns false if socket does not belong to channel" do
    socket = new_socket
    refute Socket.authenticated?(socket, "chan", "topic")
  end

  test "add_channel/3 adds channel" do
    socket = new_socket |> Socket.add_channel("test", "topic")
    assert socket.channels == [{"test", "topic"}]
  end

  test "add_channel/3 only adds unique channel/topic pairs" do
    socket = new_socket |> Socket.add_channel("test", "topic")
    assert socket.channels == [{"test", "topic"}]
    socket = Socket.add_channel(socket, "test", "topic")
    assert socket.channels == [{"test", "topic"}]
    socket = Socket.add_channel(socket, "test", "newtopic")
    assert socket.channels == [{"test", "newtopic"}, {"test", "topic"}]
  end

  test "delete_channel/3 deletes channel" do
    socket = new_socket |> Socket.add_channel("test", "topic")
    assert socket.channels == [{"test", "topic"}]
    socket = Socket.delete_channel(socket, "test", "topic")
    assert socket.channels == []
  end

  test "get_assign/2 and assign/3 assigns into the assigns map, scoped to channel/topic pair" do
    socket = new_socket |> Socket.set_current_channel("rooms", "lobby")
    refute Socket.get_assign(socket, :foo) == "bar"
    socket = Socket.assign(socket, :foo, "bar")
    assert Socket.get_assign(socket, :foo) == "bar"

    socket = socket |> Socket.set_current_channel("rooms", "123")
    refute Socket.get_assign(socket, :foo) == "bar"
    socket = Socket.assign(socket, :bar, "baz")
    assert Socket.get_assign(socket, :bar) == "baz"

    socket = socket |> Socket.set_current_channel("rooms", "lobby")
    assert Socket.get_assign(socket, :foo) == "bar"
  end

  test "get_assign/4 and assign/4 assigns for specific channel/topic pair" do
    socket = new_socket
    refute Socket.get_assign(socket, "rooms", "lobby", :foo) == "bar"
    socket = Socket.assign(socket, "rooms", "lobby", :foo, "bar")
    assert Socket.get_assign(socket, "rooms", "lobby", :foo) == "bar"

    refute Socket.get_assign(socket, "rooms", "123", :foo) == "baz"
    socket = Socket.assign(socket, "rooms", "123", :foo, "baz")
    assert Socket.get_assign(socket, "rooms", "123", :foo) == "baz"
    assert Socket.get_assign(socket, "rooms", "lobby", :foo) == "bar"
  end

end

