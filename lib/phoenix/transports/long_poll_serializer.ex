defmodule Phoenix.Transports.LongPollSerializer do
  @moduledoc false

  @behaviour Phoenix.Transports.Serializer

  alias Phoenix.Socket.{Reply, Message, Broadcast}

  @doc """
  Translates a `Phoenix.Socket.Broadcast` into a `Phoenix.Socket.Message`.
  """
  def fastlane!(%Broadcast{} = broadcast) do
    {:socket_push, :text, to_map(broadcast)}
  end

  @doc """
  Normalizes a `Phoenix.Socket.Message` struct.

  Encoding is handled downstream in the LongPoll controller.
  """
  def encode!(message) do
    {:socket_push, :text, to_map(message)}
  end

  defp to_map(%Reply{} = reply) do
    %{
      topic: reply.topic,
      event: "phx_reply",
      ref: reply.ref,
      join_ref: reply.ref,
      payload: %{status: reply.status, response: reply.payload}
    }
  end
  defp to_map(%Message{} = msg) do
    %{
      topic: msg.topic,
      event: msg.event,
      payload: msg.payload,
      ref: msg.ref,
      join_ref: msg.join_ref
    }
  end
  defp to_map(%Broadcast{} = bcast) do
    %{
      topic: bcast.topic,
      event: bcast.event,
      payload: bcast.payload,
      ref: nil,
      join_ref: nil
    }
  end

  @doc """
  Decodes JSON String into `Phoenix.Socket.Message` struct.
  """
  def decode!(message, _opts) do
    message
    |> Phoenix.json_library().decode!()
    |> Phoenix.Socket.Message.from_map!()
  end
end
