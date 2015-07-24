defmodule Phoenix.Transports.JSONSerializer do
  # TODO: Make this public
  @moduledoc false

  @behaviour Phoenix.Transports.Serializer

  alias Phoenix.Socket.Reply
  alias Phoenix.Socket.Message

  @doc """
  Encodes a `Phoenix.Socket.Message` struct to JSON string.
  """
  def encode!(%Reply{} = reply) do
    {:socket_push, :text, Poison.encode_to_iodata!(%Message{
      topic: reply.topic,
      event: "phx_reply",
      ref: reply.ref,
      payload: %{status: reply.status, response: reply.payload}
    })}
  end
  def encode!(%Message{} = msg) do
    {:socket_push, :text, Poison.encode_to_iodata!(msg)}
  end

  @doc """
  Decodes JSON String into `Phoenix.Socket.Message` struct.
  """
  def decode!(message, :text) do
    message
    |> Poison.decode!()
    |> Phoenix.Socket.Message.from_map!()
  end
end
