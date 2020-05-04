defmodule Phoenix.Socket.V2.JSONSerializerTest do
  use ExUnit.Case, async: true
  alias Phoenix.Socket.{Broadcast, Message, Reply, V2}

  @serializer V2.JSONSerializer
  @v2_fastlane_json "[null,null,\"t\",\"e\",\"m\"]"
  @v2_reply_json "[null,null,\"t\",\"phx_reply\",{\"response\":\"m\",\"status\":null}]"
  @v2_msg_json "[null,null,\"t\",\"e\",\"m\"]"

  def encode!(serializer, msg) do
    {:socket_push, :text, encoded} = serializer.encode!(msg)
    assert is_list(encoded)
    IO.iodata_to_binary(encoded)
  end

  def decode!(serializer, msg, opts \\ []) do
    serializer.decode!(msg, opts)
  end

  def fastlane!(serializer, msg) do
    {:socket_push, :text, encoded} = serializer.fastlane!(msg)
    assert is_list(encoded)
    IO.iodata_to_binary(encoded)
  end

  test "encode!/1 encodes `Phoenix.Socket.Message` as JSON" do
    msg = %Message{topic: "t", event: "e", payload: "m"}
    assert encode!(@serializer, msg) == @v2_msg_json
  end

  test "encode!/1 encodes `Phoenix.Socket.Reply` as JSON" do
    msg = %Reply{topic: "t", payload: "m"}
    assert encode!(@serializer, msg) == @v2_reply_json
  end

  test "decode!/2 decodes `Phoenix.Socket.Message` from JSON" do
    assert %Message{topic: "t", event: "e", payload: "m"} ==
      decode!(@serializer, @v2_msg_json)
  end

  test "fastlane!/1 encodes a broadcast into a message as JSON" do
    msg = %Broadcast{topic: "t", event: "e", payload: "m"}
    assert fastlane!(@serializer, msg) == @v2_fastlane_json
  end
end
