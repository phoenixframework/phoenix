defmodule Phoenix.Transports.JSONSerializer do

  @moduledoc false

  @behaviour Phoenix.Transports.Serializer

  @doc """
  Encodes a `Phoenix.Socket.Message` struct to JSON string.
  """
  def encode!(message), do: {:text, Poison.encode_to_iodata!(message)}

  @doc """
  Decodes JSON String into `Phoenix.Socket.Message` struct.
  """
  def decode!(message, :text) do
    message
    |> Poison.decode!
    |> Phoenix.Socket.Message.from_map!
  end
end
