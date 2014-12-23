defmodule Phoenix.Tranports.JSONSerializerTest do
  use ExUnit.Case, async: true

  alias Phoenix.Transports.JSONSerializer
  alias Phoenix.Socket.Message

  @msg_json "{\"message\":\"m\",\"event\":\"e\",\"channel\":\"c\"}"

  test "encode!/1 encodes `Phoenix.Socket.Message` as JSON" do
    msg = %Message{channel: "c", event: "e", message: "m"}

    assert JSONSerializer.encode!(msg) |> to_string == @msg_json
  end

  test "decode!/1 decodes `Phoenix.Socket.Message` from JSON" do
    assert %Message{channel: "c", event: "e", message: "m"} ==
      JSONSerializer.decode!(@msg_json)
  end
end
