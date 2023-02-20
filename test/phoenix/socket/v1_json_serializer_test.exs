defmodule Phoenix.Socket.V1.JSONSerializerTest do
  use ExUnit.Case, async: true

  alias Phoenix.Socket.{Broadcast, Message, Reply, V1}

  # v1 responses must not contain join_ref
  @serializer V1.JSONSerializer
  @v1_msg_json "{\"event\":\"e\",\"payload\":\"m\",\"ref\":null,\"topic\":\"t\"}"
  @v1_bad_json "[null,null,\"t\",\"e\",{\"m\":1}]"
  @v1_reply_json "{\"event\":\"phx_reply\",\"payload\":{\"response\":null,\"status\":null},\"ref\":\"null\",\"topic\":\"t\"}"
  @v1_fastlane_json "{\"event\":\"e\",\"payload\":\"m\",\"ref\":null,\"topic\":\"t\"}"

  def encode!(serializer, msg) do
    {:socket_push, :text, encoded} = serializer.encode!(msg)
    IO.iodata_to_binary(encoded)
  end

  def decode!(serializer, msg, opts), do: serializer.decode!(msg, opts)

  def fastlane!(serializer, msg) do
    {:socket_push, :text, encoded} = serializer.fastlane!(msg)
    IO.iodata_to_binary(encoded)
  end

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

  test "decode!/2 raise a PayloadFormatException if the JSON doesn't contain a map" do
    assert_raise(
      RuntimeError,
      "V1 JSON Serializer expected a map, got [nil, nil, \"t\", \"e\", %{\"m\" => 1}]",
      fn -> decode!(@serializer, @v1_bad_json, opcode: :text) end
    )
  end

  test "fastlane!/1 encodes a broadcast into a message as JSON" do
    msg = %Broadcast{topic: "t", event: "e", payload: "m"}
    assert fastlane!(@serializer, msg) == @v1_fastlane_json
  end
end
