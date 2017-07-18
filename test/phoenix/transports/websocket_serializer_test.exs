defmodule Phoenix.Tranports.WebSocketSerializerTest do
  use ExUnit.Case, async: true

  alias Phoenix.Transports.{V2, WebSocketSerializer}
  alias Phoenix.Socket.Message

  @msg_json [123, [[34, ["topic"], 34], 58, [34, ["t"], 34], 44, [34, ["ref"], 34], 58, "null", 44, [34, ["payload"], 34], 58, [34, ["m"], 34], 44, [34, ["event"], 34], 58, [34, ["e"], 34]], 125]
  @msg_json_2 [91, ["null", 44, "null", 44, [34, ["t"], 34], 44, [34, ["e"], 34], 44, [34, ["m"], 34]], 93]


  describe "version 1.0.0" do
    test "encode!/1 encodes `Phoenix.Socket.Message` as JSON" do
      msg = %Message{topic: "t", event: "e", payload: "m"}
      assert WebSocketSerializer.encode!(msg) == {:socket_push, :text, @msg_json}
    end

    test "decode!/2 decodes `Phoenix.Socket.Message` from JSON" do
      assert %Message{topic: "t", event: "e", payload: "m"} ==
        WebSocketSerializer.decode!(@msg_json, opcode: :text)
    end
  end

  describe "version 2.0.0" do
    test "encode!/1 encodes `Phoenix.Socket.Message` as JSON" do
      msg = %Message{topic: "t", event: "e", payload: "m"}
      assert V2.WebSocketSerializer.encode!(msg) == {:socket_push, :text, @msg_json_2}
    end

    test "decode!/2 decodes `Phoenix.Socket.Message` from JSON" do
      assert %Message{topic: "t", event: "e", payload: "m"} ==
        V2.WebSocketSerializer.decode!(@msg_json_2, opcode: :text)
    end
  end
end
