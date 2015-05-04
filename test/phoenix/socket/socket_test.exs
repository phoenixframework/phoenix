defmodule Phoenix.Socket.SocketTest do
  use ExUnit.Case, async: true

  alias Phoenix.Socket
  doctest Phoenix.Socket

  def new_socket do
    %Phoenix.Socket{}
  end

  test "put_topic/2 sets the topic" do
    socket = new_socket |> Socket.put_topic("sometopic:somesubtopic")
    assert socket.topic == "sometopic:somesubtopic"
  end

  test "put_channel/2 sets the channel" do
    socket = new_socket |> Socket.put_channel(MyChannel)
    assert socket.channel == MyChannel
  end

  test "socket assigns can be accessed from assigns map" do
    socket = new_socket |> Socket.assign(:key, :val)
    assert socket.assigns[:key] == :val
  end
end
