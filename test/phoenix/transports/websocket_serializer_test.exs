defmodule Phoenix.Tranports.WebSocketSerializerTest do
  use ExUnit.Case, async: true

  alias Phoenix.Transports.{V2, WebSocketSerializer}
  alias Phoenix.Socket.{Broadcast, Message, Reply}

  # v1 responses must not contain join_ref
  @v1_msg_json ["{\"", [[], "event"], "\":", [34, [], "e", 34], ",\"", [[], "payload"], "\":", [34, [], "m", 34], ",\"", [[], "ref"], "\":", "null", ",\"", [[], "topic"], "\":", [34, [], "t", 34], 125]
  @v1_reply_json ["{\"", [[], "event"], "\":", [34, [], "phx_reply", 34], ",\"", [[], "payload"], "\":", ["{\"", [[], "response"], "\":", "null", ",\"", [[], "status"], "\":", "null", 125], ",\"", [[], "ref"], "\":", [34, [], "null", 34], ",\"", [[], "topic"], "\":", [34, [], "t", 34], 125]
  @v1_fastlane_json ["{\"", [[], "event"], "\":", [34, [], "e", 34], ",\"", [[], "payload"], "\":", [34, [], "m", 34], ",\"", [[], "ref"], "\":", "null", ",\"", [[], "topic"], "\":", [34, [], "t", 34], 125]
  @v2_msg_json [91, "null", 44, "null", 44, [34, [], "t", 34], 44, [34, [], "e", 34], 44, [34, [], "m", 34], 93]

  describe "version 1.0.0" do
    test "encode!/1 encodes `Phoenix.Socket.Message` as JSON" do
      msg = %Message{topic: "t", event: "e", payload: "m"}
      assert WebSocketSerializer.encode!(msg) == {:socket_push, :text, @v1_msg_json}
    end

    test "encode!/1 encodes `Phoenix.Socket.Reply` as JSON" do
      msg = %Reply{topic: "t", ref: "null"}
      assert WebSocketSerializer.encode!(msg) == {:socket_push, :text, @v1_reply_json}
    end

    test "decode!/2 decodes `Phoenix.Socket.Message` from JSON" do
      assert %Message{topic: "t", event: "e", payload: "m"} ==
        WebSocketSerializer.decode!(@v1_msg_json, opcode: :text)
    end

    test "fastlane!/1 encodes a broadcast into a message as JSON" do
      msg = %Broadcast{topic: "t", event: "e", payload: "m"}
      assert WebSocketSerializer.fastlane!(msg) == {:socket_push, :text, @v1_fastlane_json}
    end
  end

  describe "version 2.0.0" do
    test "encode!/1 encodes `Phoenix.Socket.Message` as JSON" do
      msg = %Message{topic: "t", event: "e", payload: "m"}
      assert V2.WebSocketSerializer.encode!(msg) == {:socket_push, :text, @v2_msg_json}
    end

    test "decode!/2 decodes `Phoenix.Socket.Message` from JSON" do
      assert %Message{topic: "t", event: "e", payload: "m"} ==
        V2.WebSocketSerializer.decode!(@v2_msg_json, opcode: :text)
    end
  end
end
