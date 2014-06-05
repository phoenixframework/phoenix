defmodule Phoenix.Socket.Message do
  use Jazz
  alias Phoenix.Socket.Message

  defstruct channel: nil, topic: nil, event: nil, message: nil

  defmodule InvalidMessage do
    defexception [:message]
    def exception(msg) do
      %InvalidMessage{message: "Invalid Socket Message: #{inspect msg}"}
    end
  end

  @doc """
  Parse json message into required format, raise InvalidMessage if invalid

  The Message Protocol requires the following keys:
    * channel - The String Channel namespace, ie "messages"
    * topic - The String Topic namespace, ie "123"
    * event - The String event name, ie "join"
    * message - The String JSON message payload

  Returns The %Message{} parsed from JSON
  """
  def parse!(text) do
    try do
      json = JSON.decode!(text)

      %Message{
        channel: Dict.fetch!(json, "channel"),
        topic:   Dict.fetch!(json, "topic"),
        event:   Dict.fetch!(json, "event"),
        message: Dict.fetch!(json, "message")
      }
    rescue
      err in [KeyError]         -> raise InvalidMessage, message: "Missing key: '#{err.key}'"
      err in [JSON.SyntaxError] -> raise InvalidMessage, message: "Invalid JSON: #{err.message}"
    end
  end
end
