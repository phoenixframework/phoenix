defmodule Phoenix.Socket.V2.JSONSerializerTest do
  use ExUnit.Case, async: true
  alias Phoenix.Socket.{Broadcast, Message, Reply, V2}

  @serializer V2.JSONSerializer
  @v2_fastlane_json "[null,null,\"t\",\"e\",{\"m\":1}]"
  @v2_msg_json "[null,null,\"t\",\"e\",{\"m\":1}]"

  @client_push <<
    # push
    0::size(8),
    # join_ref_size
    2,
    # ref_size
    3,
    # topic_size
    5,
    # event_size
    5,
    "12",
    "123",
    "topic",
    "event",
    101,
    102,
    103
  >>

  @reply <<
    # reply
    1::size(8),
    # join_ref_size
    2,
    # ref_size
    3,
    # topic_size
    5,
    # status_size
    2,
    "12",
    "123",
    "topic",
    "ok",
    101,
    102,
    103
  >>

  @broadcast <<
    # broadcast
    2::size(8),
    # topic_size
    5,
    # event_size
    5,
    "topic",
    "event",
    101,
    102,
    103
  >>

  def encode!(serializer, msg) do
    case serializer.encode!(msg) do
      {:socket_push, :text, encoded} ->
        assert is_list(encoded)
        IO.iodata_to_binary(encoded)

      {:socket_push, :binary, encoded} ->
        assert is_binary(encoded)
        encoded
    end
  end

  def decode!(serializer, msg, opts \\ []) do
    serializer.decode!(msg, opts)
  end

  def fastlane!(serializer, msg) do
    case serializer.fastlane!(msg) do
      {:socket_push, :text, encoded} ->
        assert is_list(encoded)
        IO.iodata_to_binary(encoded)

      {:socket_push, :binary, encoded} ->
        assert is_binary(encoded)
        encoded
    end
  end

  test "encode!/1 encodes `Phoenix.Socket.Message` as JSON" do
    msg = %Message{topic: "t", event: "e", payload: %{m: 1}}
    assert encode!(@serializer, msg) == @v2_msg_json
  end

  test "encode!/1 raises when payload is not a map" do
    msg = %Message{topic: "t", event: "e", payload: "invalid"}
    assert_raise ArgumentError, fn -> encode!(@serializer, msg) end
  end

  test "encode!/1 encodes `Phoenix.Socket.Reply` as JSON" do
    msg = %Reply{topic: "t", payload: %{m: 1}}
    encoded = encode!(@serializer, msg)

    assert Jason.decode!(encoded) == [
             nil,
             nil,
             "t",
             "phx_reply",
             %{"response" => %{"m" => 1}, "status" => nil}
           ]
  end

  test "decode!/2 decodes `Phoenix.Socket.Message` from JSON" do
    assert %Message{topic: "t", event: "e", payload: %{"m" => 1}} ==
             decode!(@serializer, @v2_msg_json, opcode: :text)
  end

  test "fastlane!/1 encodes a broadcast into a message as JSON" do
    msg = %Broadcast{topic: "t", event: "e", payload: %{m: 1}}
    assert fastlane!(@serializer, msg) == @v2_fastlane_json
  end

  test "fastlane!/1 raises when payload is not a map" do
    msg = %Broadcast{topic: "t", event: "e", payload: "invalid"}
    assert_raise ArgumentError, fn -> fastlane!(@serializer, msg) end
  end

  describe "binary encode" do
    test "general pushed message" do
      push = <<
        # push
        0::size(8),
        # join_ref_size
        2,
        # topic_size
        5,
        # event_size
        5,
        "12",
        "topic",
        "event",
        101,
        102,
        103
      >>

      assert encode!(@serializer, %Phoenix.Socket.Message{
               join_ref: "12",
               ref: nil,
               topic: "topic",
               event: "event",
               payload: {:binary, <<101, 102, 103>>}
             }) == push
    end

    test "encode with oversized headers" do
      assert_raise ArgumentError, ~r/unable to convert topic to binary/, fn ->
        encode!(@serializer, %Phoenix.Socket.Message{
          join_ref: "12",
          ref: nil,
          topic: String.duplicate("t", 256),
          event: "event",
          payload: {:binary, <<101, 102, 103>>}
        })
      end

      assert_raise ArgumentError, ~r/unable to convert event to binary/, fn ->
        encode!(@serializer, %Phoenix.Socket.Message{
          join_ref: "12",
          ref: nil,
          topic: "topic",
          event: String.duplicate("e", 256),
          payload: {:binary, <<101, 102, 103>>}
        })
      end

      assert_raise ArgumentError, ~r/unable to convert join_ref to binary/, fn ->
        encode!(@serializer, %Phoenix.Socket.Message{
          join_ref: String.duplicate("j", 256),
          ref: nil,
          topic: "topic",
          event: "event",
          payload: {:binary, <<101, 102, 103>>}
        })
      end
    end

    test "reply" do
      assert encode!(@serializer, %Phoenix.Socket.Reply{
               join_ref: "12",
               ref: "123",
               topic: "topic",
               status: :ok,
               payload: {:binary, <<101, 102, 103>>}
             }) == @reply
    end

    test "reply with oversized headers" do
      assert_raise ArgumentError, ~r/unable to convert ref to binary/, fn ->
        encode!(@serializer, %Phoenix.Socket.Reply{
          join_ref: "12",
          ref: String.duplicate("r", 256),
          topic: "topic",
          status: :ok,
          payload: {:binary, <<101, 102, 103>>}
        })
      end
    end

    test "fastlane" do
      assert fastlane!(@serializer, %Phoenix.Socket.Broadcast{
               topic: "topic",
               event: "event",
               payload: {:binary, <<101, 102, 103>>}
             }) == @broadcast
    end

    test "fastlane with oversized headers" do
      assert_raise ArgumentError, ~r/unable to convert topic to binary/, fn ->
        fastlane!(@serializer, %Phoenix.Socket.Broadcast{
          topic: String.duplicate("t", 256),
          event: "event",
          payload: {:binary, <<101, 102, 103>>}
        })
      end

      assert_raise ArgumentError, ~r/unable to convert event to binary/, fn ->
        fastlane!(@serializer, %Phoenix.Socket.Broadcast{
          topic: "topic",
          event: String.duplicate("e", 256),
          payload: {:binary, <<101, 102, 103>>}
        })
      end
    end
  end

  describe "binary decode" do
    test "pushed message" do
      assert decode!(@serializer, @client_push, opcode: :binary) == %Phoenix.Socket.Message{
               join_ref: "12",
               ref: "123",
               topic: "topic",
               event: "event",
               payload: {:binary, <<101, 102, 103>>}
             }
    end
  end
end
