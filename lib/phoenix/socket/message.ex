defmodule Phoenix.Socket.Message do
  alias Poison, as: JSON
  alias Phoenix.Socket.Message

  defstruct channel: nil, event: nil, message: nil

  defmodule InvalidMessage do
    defexception [:message]
    def exception(msg) do
      %InvalidMessage{message: "Invalid Socket Message: #{inspect msg}"}
    end
  end

  @doc """
  Parse JSON into required format
  Raises `Phoenix.Socket.Message.InvalidMessage` if invalid

  The Message format requires the following keys:

    * channel - The String Channel namespace, ie "messages"
    * event - The String event name, ie "join"
    * message - The String JSON message payload

  Returns The `%Phoenix.Socket.Message{}` parsed from JSON
  """
  def parse!(text) do
    text |> JSON.decode! |> from_map!
  end

  @doc """
  Converts a map with string keys into a `%Phoenix.Socket.Message{}`.
  Raises `Phoenix.Socket.Message.InvalidMessage` if not valid

  See `parse!/1` for required keys
  """
  def from_map!(map) when is_map(map) do
    try do
      %Message{
        channel: Map.fetch!(map, "channel"),
        event:   Map.fetch!(map, "event"),
        message: Map.fetch!(map, "message")
      }
    rescue
      err in [KeyError] -> raise InvalidMessage, message: "Missing key: '#{err.key}'"
    end
  end
end
