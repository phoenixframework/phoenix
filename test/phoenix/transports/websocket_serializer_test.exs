defmodule Phoenix.Tranports.WebSocketSerializerTest do
  use ExUnit.Case, async: true

  alias Phoenix.Transports.WebSocketSerializer
  alias Phoenix.Socket.Message

  @msg_json [123, [[34, ["topic"], 34], 58, [34, ["t"], 34], 44, [34, ["ref"], 34], 58, "null", 44, [34, ["payload"], 34], 58, [34, ["m"], 34], 44, [34, ["event"], 34], 58, [34, ["e"], 34]], 125]

  test "encode!/1 encodes `Phoenix.Socket.Message` as JSON" do
    msg = %Message{topic: "t", event: "e", payload: "m"}
    assert WebSocketSerializer.encode!(msg) == {:socket_push, :text, @msg_json}
  end

  test "decode!/2 decodes `Phoenix.Socket.Message` from JSON" do
    assert %Message{topic: "t", event: "e", payload: "m"} ==
      WebSocketSerializer.decode!(@msg_json)
  end
end
