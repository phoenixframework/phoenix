defmodule Phoenix.Transports.V2.LongPollSerializer do
  @moduledoc false

  @behaviour Phoenix.Transports.Serializer

  alias Phoenix.Socket.{Reply, Message, Broadcast}

  @doc """
  Translates a `Phoenix.Socket.Broadcast` into a `Phoenix.Socket.Message`.
  """
  def fastlane!(%Broadcast{} = msg) do
    encoded =
      %Message{topic: msg.topic, event: msg.event, payload: msg.payload}
      |> to_list()
      |> Poison.encode!()

    {:socket_push, :text, encoded}
  end

  @doc """
  Normalizes a `Phoenix.Socket.Message` struct.

  Encoding is handled downstream in the LongPoll controller.
  """
  def encode!(msg) do
    {:socket_push, :text, msg |> to_list() |> Poison.encode!()}
  end
  defp to_list(%Reply{} = reply) do
    [reply.join_ref, reply.ref, reply.topic, "phx_reply",
     %{status: reply.status, response: reply.payload}]
  end
  defp to_list(%Message{} = msg) do
    [msg.join_ref, msg.ref, msg.topic, msg.event, msg.payload]
  end

  @doc """
  Decodes JSON String into `Phoenix.Socket.Message` struct.
  """
  def decode!(raw_message, _opts) do
    [join_ref, ref, topic, event, payload | _] = Poison.decode!(raw_message)

    %Phoenix.Socket.Message{
      topic: topic,
      event: event,
      payload: payload,
      ref: ref,
      join_ref: join_ref,
    }
  end
end
