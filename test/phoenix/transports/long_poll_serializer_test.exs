defmodule Phoenix.Tranports.LongPollSerializerTest do
  use ExUnit.Case, async: true

  alias Phoenix.Transports.{V2, LongPollSerializer}
  alias Phoenix.Socket.{Message, Broadcast, Reply}

  @msg_json [123, [[34, ["topic"], 34], 58, [34, ["t"], 34], 44, [34, ["ref"], 34], 58, "null", 44, [34, ["payload"], 34], 58, [34, ["m"], 34], 44, [34, ["event"], 34], 58, [34, ["e"], 34]], 125]
  @msg_json_2 [91, ["null", 44, "null", 44, [34, ["t"], 34], 44, [34, ["e"], 34], 44, [34, ["m"], 34]], 93]

  describe "v1" do
    test "fastlane!/1 translates `Phoenix.Socket.Broadcast` into 'Phoenix.Socket.Message'" do
      broadcast = %Broadcast{topic: "t", event: "e", payload: "m"}
      assert LongPollSerializer.fastlane!(broadcast) ==
        {:socket_push, :text,
          %{topic: broadcast.topic, event: broadcast.event, payload: broadcast.payload, ref: nil, join_ref: nil}}
    end

    test "encode!/1 encodes `Phoenix.Socket.Message` as JSON" do
      reply = %Reply{topic: "t", payload: "m", ref: "foo", status: "bar"}
      assert LongPollSerializer.encode!(reply) ==
        {:socket_push, :text,
          %{topic: reply.topic,
            event: "phx_reply",
            join_ref: "foo",
            ref: reply.ref, payload: %{status: reply.status, response: reply.payload}}}
    end

    test "decode!/2 decodes `Phoenix.Socket.Message` from JSON" do
      assert %Message{topic: "t", event: "e", payload: "m"} ==
        LongPollSerializer.decode!(@msg_json, opcode: :text)
    end
  end

  describe "v2" do
    test "fastlane!/1 translates `Phoenix.Socket.Broadcast` into 'Phoenix.Socket.Message'" do
      broadcast = %Broadcast{topic: "t", event: "e", payload: "m"}
      assert V2.LongPollSerializer.fastlane!(broadcast) ==
        {:socket_push, :text, Phoenix.json_library().encode_to_iodata!([nil, nil, "t", "e", "m"])}
    end

    test "encode!/1 encodes `Phoenix.Socket.Message` as JSON" do
      reply = %Reply{join_ref: "join", topic: "t", payload: "m", ref: "foo", status: "bar"}
      assert V2.LongPollSerializer.encode!(reply) ==
        {:socket_push, :text, Phoenix.json_library().encode_to_iodata!(["join", "foo", "t", "phx_reply", %{response: "m", status: "bar"}])}
    end

    test "decode!/2 decodes `Phoenix.Socket.Message` from JSON" do
      assert %Message{topic: "t", event: "e", payload: "m"} ==
        V2.LongPollSerializer.decode!(@msg_json_2, opcode: :text)
    end
  end
end
