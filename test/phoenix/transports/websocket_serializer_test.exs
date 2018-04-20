defmodule Phoenix.Tranports.WebSocketSerializerTest do
  use ExUnit.Case, async: true

  alias Phoenix.Transports.WebSocketSerializer
  alias Phoenix.Socket.{Broadcast, Message, Reply}

  # v1 responses must not contain join_ref
  @v1_msg_json ["{\"", "event", "\":", 34, "e", 34, ",\"", "payload", "\":", 34, "m", 34, ",\"", "ref", "\":", "null", ",\"", "topic", "\":", 34, "t", 34, 125]
  @v1_reply_json ["{\"", "event", "\":", 34, "phx_reply", 34, ",\"", "payload", "\":", "{\"", "response", "\":", "null", ",\"", "status", "\":", "null", 125, ",\"", "ref", "\":", 34, "null", 34, ",\"", "topic", "\":", 34, "t", 34, 125]
  @v1_fastlane_json ["{\"", "event", "\":", 34, "e", 34, ",\"", "payload", "\":", 34, "m", 34, ",\"", "ref", "\":", "null", ",\"", "topic", "\":", 34, "t", 34, 125]

  def encode!(serializer, msg) do
    {:socket_push, :text, encoded} = serializer.encode!(msg)
    List.flatten(encoded)
  end

  def decode!(serializer, msg, opts), do: serializer.decode!(msg, opts)

  def fastlane!(serializer, msg) do
    {:socket_push, :text, encoded} = serializer.fastlane!(msg)
    List.flatten(encoded)
  end

  @serializer WebSocketSerializer

  test "encode!/1 encodes `Phoenix.Socket.Message` as JSON" do
    msg = %Message{topic: "t", event: "e", payload: "m"}
    assert encode!(@serializer, msg) == @v1_msg_json
  end

  test "encode!/1 encodes `Phoenix.Socket.Reply` as JSON" do
    msg = %Reply{topic: "t", ref: "null"}
    assert encode!(@serializer, msg) == @v1_reply_json
  end

  test "decode!/2 decodes `Phoenix.Socket.Message` from JSON" do
    assert %Message{topic: "t", event: "e", payload: "m"} ==
      decode!(@serializer, @v1_msg_json, opcode: :text)
  end

  test "fastlane!/1 encodes a broadcast into a message as JSON" do
    msg = %Broadcast{topic: "t", event: "e", payload: "m"}
    assert fastlane!(@serializer, msg) == @v1_fastlane_json
  end
end
