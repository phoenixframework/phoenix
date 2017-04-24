defmodule Phoenix.Transports.LongPollSerializer do
  @moduledoc false

  @behaviour Phoenix.Transports.Serializer

  alias Phoenix.Socket.{Reply, Message, Broadcast}

  @doc """
  Translates a `Phoenix.Socket.Broadcast` into a `Phoenix.Socket.Message`.
  """
  def fastlane!(%Broadcast{} = broadcast) do
    {:socket_push, :text, to_msg(broadcast)}
  end

  @doc """
  Normalizes a `Phoenix.Socket.Message` struct.

  Encoding is handled downstream in the LongPoll controller.
  """
  def encode!(message) do
    {:socket_push, :text, to_msg(message)}
  end

  defp to_msg(%Reply{} = reply) do
    %Message{
      topic: reply.topic,
      event: "phx_reply",
      ref: reply.ref,
      join_ref: reply.ref,
      payload: %{status: reply.status, response: reply.payload}
    }
  end
  defp to_msg(%Message{} = msg), do: msg
  defp to_msg(%Broadcast{} = bcast) do
    %Message{topic: bcast.topic, event: bcast.event, payload: bcast.payload}
  end

  @doc """
  Decodes JSON String into `Phoenix.Socket.Message` struct.
  """
  def decode!(message, _opts) do
    message
    |> Poison.decode!()
    |> Phoenix.Socket.Message.from_map!()
  end
end
