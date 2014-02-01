defmodule Phoenix.Controller.WebsocketTest do
  use ExUnit.Case, async: true
  alias Phoenix.Controller.Websocket

  defrecord Socket, conn: nil, pid: nil

  test "verify correct return from terminate" do
    Websocket.terminate(Socket.new(pid: self()))
    assert_received :shutdown
  end

  test "verify correct return from hibernate" do
    Websocket.hibernate(Socket.new(pid: self))
    assert_received :hibernate
  end

  test "verify basic reply" do
    Websocket.reply(Socket.new(pid: self), {:text, "hello"})
    assert_received {:send, {:text, "hello"}, []}
  end
end
