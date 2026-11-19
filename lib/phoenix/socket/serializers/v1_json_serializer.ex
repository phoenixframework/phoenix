defmodule Phoenix.Socket.V1.JSONSerializer do
  @moduledoc false
  @behaviour Phoenix.Socket.Serializer

  alias Phoenix.Socket.{Broadcast, Message, Reply}

  @impl true
  def fastlane!(%Broadcast{payload: {:binary, _}} = msg) do
    raise_binary_payload!(msg.topic)
  end

  def fastlane!(%Broadcast{} = msg) do
    map = %Message{topic: msg.topic, event: msg.event, payload: msg.payload}
    {:socket_push, :text, encode_v1_fields_only(map)}
  end

  @impl true
  def encode!(%Reply{payload: {:binary, _}} = reply) do
    raise_binary_payload!(reply.topic)
  end

  def encode!(%Message{payload: {:binary, _}} = msg) do
    raise_binary_payload!(msg.topic)
  end

  def encode!(%Reply{} = reply) do
    map = %Message{
      topic: reply.topic,
      event: "phx_reply",
      ref: reply.ref,
      payload: %{status: reply.status, response: reply.payload}
    }

    {:socket_push, :text, encode_v1_fields_only(map)}
  end

  def encode!(%Message{} = map) do
    {:socket_push, :text, encode_v1_fields_only(map)}
  end

  @impl true
  def decode!(message, _opts) do
    payload = Phoenix.json_library().decode!(message)

    case payload do
      %{} ->
        Phoenix.Socket.Message.from_map!(payload)

      other ->
        raise "V1 JSON Serializer expected a map, got #{inspect(other)}"
    end
  end

  defp raise_binary_payload!(topic) do
    raise ArgumentError, """
    unable to send a binary payload on topic #{inspect(topic)}.

    The client connected with the V1 serializer, which only supports JSON payloads. \
    Clients must connect with vsn=2.0.0 to receive binary payloads.
    """
  end

  defp encode_v1_fields_only(%Message{} = msg) do
    msg
    |> Map.take([:topic, :event, :payload, :ref])
    |> Phoenix.json_library().encode_to_iodata!()
  end
end
