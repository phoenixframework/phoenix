defmodule Phoenix.Socket.Message do
  alias Poison, as: JSON
  alias Phoenix.Socket.Message

  defstruct channel: nil, topic: nil, event: nil, message: nil

  defmodule InvalidMessage do
    defexception [:message]
    def exception(msg) do
      %InvalidMessage{message: "Invalid Socket Message: #{inspect msg}"}
    end
  end

  @doc """
  Parse JSON into required format, raises `Phoenix.Socket.InvalidMessage` if invalid

  The Message format requires the following keys:

    * channel - The String Channel namespace, ie "messages"
    * topic - The String Topic namespace, ie "123"
    * event - The String event name, ie "join"
    * message - The String JSON message payload

  Returns The %Message{} parsed from JSON
  """
  def parse!(text) do
    try do
      text |> JSON.decode! |> from_map!
    rescue
      err in [JSON.SyntaxError] -> raise InvalidMessage, message: "Invalid JSON: #{err.message}"
    end
  end

  @doc """
  Converts a map with string keys into a `%Phoenix.Socket.Message{}`.
  Raises `InvalidMessage` if not valid

  See `parse!/1` for required keys
  """
  def from_map!(map) do
    try do
      %Message{
        channel: Dict.fetch!(map, "channel"),
        topic:   Dict.fetch!(map, "topic"),
        event:   Dict.fetch!(map, "event"),
        message: Dict.fetch!(map, "message")
      }
    rescue
      err in [KeyError] -> raise InvalidMessage, message: "Missing key: '#{err.key}'"
    end
  end
end
