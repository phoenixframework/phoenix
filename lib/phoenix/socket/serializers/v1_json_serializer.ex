defmodule Phoenix.Socket.V1.JSONSerializer do
  @moduledoc false
  @behaviour Phoenix.Socket.Serializer

  alias Phoenix.Socket.{Broadcast, Message, Reply}

  @impl true
  def fastlane!(%Broadcast{} = msg) do
    map = %Message{topic: msg.topic, event: msg.event, payload: msg.payload}
    {:socket_push, :text, encode_v1_fields_only(map)}
  end

  @impl true
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
    message
    |> Phoenix.json_library().decode!()
    |> Phoenix.Socket.Message.from_map!()
  end

  defp encode_v1_fields_only(%Message{} = msg) do
    msg
    |> Map.take([:topic, :event, :payload, :ref])
    |> Phoenix.json_library().encode_to_iodata!()
  end
end
