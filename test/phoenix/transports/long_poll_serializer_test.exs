defmodule Phoenix.Tranports.LongPollSerializerTest do
  use ExUnit.Case, async: true

  alias Phoenix.Transports.LongPollSerializer
  alias Phoenix.Socket.Message
  alias Phoenix.Socket.Broadcast
  alias Phoenix.Socket.Reply

  @msg_json [123, [[34, ["topic"], 34], 58, [34, ["t"], 34], 44, [34, ["ref"], 34], 58, "null", 44, [34, ["payload"], 34], 58, [34, ["m"], 34], 44, [34, ["event"], 34], 58, [34, ["e"], 34]], 125]

  test "fastlane!/1 translates `Phoenix.Socket.Broadcast` into 'Phoenix.Socket.Message'" do
    broadcast = %Broadcast{topic: "t", event: "e", payload: "m"}
    assert LongPollSerializer.fastlane!(broadcast) == %Message{topic: broadcast.topic, event: broadcast.event, payload: broadcast.payload}
  end

  test "encode!/1 encodes `Phoenix.Socket.Message` as JSON" do
    reply = %Reply{topic: "t", payload: "m", ref: "foo", status: "bar"}
    assert LongPollSerializer.encode!(reply) == %Message{topic: reply.topic, event: "phx_reply", ref: reply.ref, payload: %{status: reply.status, response: reply.payload}}
  end

  test "decode!/2 decodes `Phoenix.Socket.Message` from JSON" do
    assert %Message{topic: "t", event: "e", payload: "m"} ==
      LongPollSerializer.decode!(@msg_json, opcode: :text)
  end
end
