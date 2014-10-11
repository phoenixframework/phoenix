defmodule Phoenix.Socket.MessageTest do
  use ExUnit.Case, async: true

  alias Phoenix.Socket.Message
  alias Phoenix.Socket.Message.InvalidMessage

  test "parse! returns map when given valid json with required keys" do
    message = Message.parse!("""
    {"channel": "c","topic":"t","event":"e","message":"m"}
    """)

    assert message.channel == "c"
    assert message.topic == "t"
    assert message.event == "e"
    assert message.message == "m"
  end

  test "parse! raises InvalidMessage when given invalid json" do
    assert_raise InvalidMessage, fn ->
      Message.parse!("""
      {INVALID"channel": "c","topic":"t","event":"e","message":"m"}
      """)
    end
  end

  test "parse! raise InvalidMessage when missing :channel key" do
    assert_raise InvalidMessage, fn ->
      Message.parse!("""
      {"topic":"t","event":"e","message":"m"}
      """)
    end
  end

  test "parse! raise InvalidMessage when missing :topic key" do
    assert_raise InvalidMessage, fn ->
      Message.parse!("""
      {"channel": "c","event":"e","message":"m"}
      """)
    end
  end

  test "parse! raise InvalidMessage when missing :event key" do
    assert_raise InvalidMessage, fn ->
      Message.parse!("""
      {"channel": "c","topic":"t","message":"m"}
      """)
    end
  end

  test "parse! raise InvalidMessage when missing :message key" do
    assert_raise InvalidMessage, fn ->
      Message.parse!("""
      {"channel": "c","topic":"t","event":"e"}
      """)
    end
  end
end

