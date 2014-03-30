defmodule Phoenix.Socket.HandlerTest do
  use ExUnit.Case
  alias Phoenix.Socket
  alias Phoenix.Socket.Handler

  def new_socket do
    %Socket{pid: self,
            router: nil,
            channels: [],
            assigns: []}
  end

  test "#authenticated? returns true if socket belongs to channel" do
    socket = new_socket
    socket = Handler.add_channel(socket, "topic")
    assert Handler.authenticated?(socket, "topic")
  end

  test "#authenticated? returns false if socket does not belong to channel" do
    socket = new_socket
    refute Handler.authenticated?(socket, "topic")
  end
end

