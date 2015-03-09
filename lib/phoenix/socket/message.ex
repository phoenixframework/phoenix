defmodule Phoenix.Socket.Message do

  @moduledoc """
  Defines a `Phoenix.Socket` Message dispatched over channels.

  The Message format requires the following keys:

    * topic - The String topic or topic:subtopic pair namespace, ie "messages", "messages:123"
    * event - The String event name, ie "join"
    * payload - The String JSON message payload

  """

  alias Phoenix.Socket.Message

  defstruct topic: nil, event: nil, payload: nil

  defmodule InvalidMessage do
    defexception [:message]
    def exception(msg) do
      %InvalidMessage{message: "Invalid Socket Message: #{inspect msg}"}
    end
  end

  @doc """
  Converts a map with string keys into a `%Phoenix.Socket.Message{}`.
  Raises `Phoenix.Socket.Message.InvalidMessage` if not valid.
  """
  def from_map!(map) when is_map(map) do
    try do
      %Message{
        topic: Map.fetch!(map, "topic"),
        event:   Map.fetch!(map, "event"),
        payload: Map.fetch!(map, "payload")
      }
    rescue
      err in [KeyError] -> raise InvalidMessage, message: "Missing key: '#{err.key}'"
    end
  end
end
