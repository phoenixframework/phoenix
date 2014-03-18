defmodule Phoenix.Controller.WebsocketTest do
  use ExUnit.Case, async: true
  import Phoenix.Websocket.Handler

  defrecord Socket, conn: nil, pid: nil

  test "verify correct return from terminate" do
    terminate(Socket.new(pid: self))
    assert_received :shutdown
  end

  test "verify correct return from hibernate" do
    hibernate(Socket.new(pid: self))
    assert_received :hibernate
  end

  test "verify basic reply" do
    reply(Socket.new(pid: self), {:text, "hello"})
    assert_received {:send, {:text, "hello"}, []}
  end
end
