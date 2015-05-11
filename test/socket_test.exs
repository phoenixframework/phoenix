defmodule Phoenix.SocketTest do
  use ExUnit.Case, async: true

  alias Phoenix.Socket.Message
  alias Phoenix.Socket.InvalidMessageError

  test "from_map! converts a map with string keys into a %Message{}" do
    msg = Message.from_map!(%{"topic" => "c", "event" => "e", "payload" => "", "ref" => "r"})
    assert msg == %Message{topic: "c", event: "e", payload: "", ref: "r"}
  end

  test "from_map! raises InvalidMessageError when any required key" do
    assert_raise InvalidMessageError, fn ->
      Message.from_map!(%{"event" => "e", "payload" => "", "ref" => "r"})
    end
    assert_raise InvalidMessageError, fn ->
      Message.from_map!(%{"topic" => "c", "payload" => "", "ref" => "r"})
    end
    assert_raise InvalidMessageError, fn ->
      Message.from_map!(%{"topic" => "c", "event" => "e", "ref" => "r"})
    end
    assert_raise InvalidMessageError, fn ->
      Message.from_map!(%{"topic" => "c", "event" => "e"})
    end
  end
end
