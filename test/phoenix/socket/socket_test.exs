defmodule Phoenix.Socket.SocketTest do
  use ExUnit.Case
  alias Phoenix.Socket

  def new_socket do
    %Socket{pid: self,
            router: nil,
            channels: [],
            assigns: %{}}
  end

  test "#set_current_channel sets the current channel" do
    socket = new_socket |> Socket.set_current_channel("somechan", "sometopic")
    assert socket.channel == "somechan"
    assert socket.topic == "sometopic"
  end

  test "#authenticated? returns true if socket belongs to channel scoped to topic" do
    socket = new_socket
    socket = Socket.add_channel(socket, "channel", "topic")
    assert Socket.authenticated?(socket, "channel", "topic")
    refute Socket.authenticated?(socket, "channel", "othertopic")
  end

  test "#authenticated? returns false if socket does not belong to channel" do
    socket = new_socket
    refute Socket.authenticated?(socket, "chan", "topic")
  end

  test "#add_channel adds channel" do
    socket = new_socket |> Socket.add_channel("test", "topic")
    assert socket.channels == [{"test", "topic"}]
  end

  test "#add_channel only adds unique channel/topic pairs" do
    socket = new_socket |> Socket.add_channel("test", "topic")
    assert socket.channels == [{"test", "topic"}]
    socket = Socket.add_channel(socket, "test", "topic")
    assert socket.channels == [{"test", "topic"}]
    socket = Socket.add_channel(socket, "test", "newtopic")
    assert socket.channels == [{"test", "newtopic"}, {"test", "topic"}]
  end

  test "#delete_channel deletes channel" do
    socket = new_socket |> Socket.add_channel("test", "topic")
    assert socket.channels == [{"test", "topic"}]
    socket = Socket.delete_channel(socket, "test", "topic")
    assert socket.channels == []
  end

  test "#assign assigns into the assigns map (yo dog)" do
    socket = new_socket
    assert socket.assigns == %{}
    socket = Socket.assign(socket, :foo, "bar")
    assert socket.assigns == %{foo: "bar"}
  end
end

