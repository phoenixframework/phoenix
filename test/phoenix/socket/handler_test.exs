defmodule Phoenix.Socket.HandlerTest do
  use ExUnit.Case, async: true
  import Phoenix.Socket.Handler
  alias Phoenix.Socket

  test "verify correct return from terminate" do
    terminate(%Socket{pid: self})
    assert_received :shutdown
  end

  test "verify correct return from hibernate" do
    hibernate(%Socket{pid: self})
    assert_received :hibernate
  end

  test "verify basic reply" do
    socket = %Socket{pid: self}
    reply(socket, {:text, "hello"})
    assert_received {:reply, {:text, "hello"}, socket}
  end
end
