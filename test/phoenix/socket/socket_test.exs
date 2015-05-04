defmodule Phoenix.Socket.SocketTest do
  use ExUnit.Case, async: true

  import Phoenix.Socket

  def new_socket do
    %Phoenix.Socket{}
  end

  test "put_topic/2 sets the topic" do
    socket = new_socket |> put_topic("sometopic:somesubtopic")
    assert socket.topic == "sometopic:somesubtopic"
  end

  test "socket assigns can be accessed from assigns map" do
    socket = new_socket |> assign(:key, :val)
    assert socket.assigns[:key] == :val
  end
end
