defmodule Phoenix.Transports.WebSocketSerializer do
  @moduledoc false

  @behaviour Phoenix.Transports.Serializer

  alias Phoenix.Socket.Reply
  alias Phoenix.Socket.Message
  alias Phoenix.Socket.Broadcast

  @doc """
  Translates a `Phoenix.Socket.Broadcast` into a `Phoenix.Socket.Message`.
  """
  def fastlane!(%Broadcast{} = msg) do
    msg = %Message{topic: msg.topic, event: msg.event, payload: msg.payload}

    {:socket_push, :text, encode_v1_fields_only(msg)}
  end

  @doc """
  Encodes a `Phoenix.Socket.Message` struct to JSON string.
  """
  def encode!(%Reply{} = reply) do
    msg = %Message{
      topic: reply.topic,
      event: "phx_reply",
      ref: reply.ref,
      payload: %{status: reply.status, response: reply.payload}
    }

    {:socket_push, :text, encode_v1_fields_only(msg)}
  end
  def encode!(%Message{} = msg) do
    {:socket_push, :text, encode_v1_fields_only(msg)}
  end

  @doc """
  Decodes JSON String into `Phoenix.Socket.Message` struct.
  """
  def decode!(message, _opts) do
    message
    |> Poison.decode!()
    |> Phoenix.Socket.Message.from_map!()
  end

  defp encode_v1_fields_only(%Message{} = msg) do
    msg
    |> Map.take([:topic, :event, :payload, :ref])
    |> Poison.encode_to_iodata!()
  end
end
