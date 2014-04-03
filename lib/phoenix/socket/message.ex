defmodule Phoenix.Socket.Message do
  alias Phoenix.Socket.Message

  defstruct channel: nil, topic: nil, event: nil, message: nil

  defexception InvalidMessage, message: nil do
    def exception(options) do
      message = options[:message]
      InvalidMessage[message: "Invalid Socket Message: #{inspect message}"]
    end
  end

  @doc """
  Parse json message into required format, raise InvalidMessage if invalid

  The Message Protocol requires the following keys:
    * channel - The String Channel namespace, ie "messages"
    * topic - The String Topic namespace, ie "123"
    * event - The String event name, ie "join"
    * message - The String JSON message payload

  Returns The Message Map parsed from JSON
  """
  def parse!(text) do
    case JSON.decode(text) do
      {:ok, json} ->
        try do
          %Message{
            channel: Dict.fetch!(json, "channel"),
            topic:   Dict.fetch!(json, "topic"),
            event:   Dict.fetch!(json, "event"),
            message: Dict.fetch!(json, "message")
          }
       rescue
         err in [KeyError] ->
          raise InvalidMessage, message: "Missing required key: '#{err.key}'"
       end
      {:error, err, _} -> raise InvalidMessage, message: "Invalid JSON format: #{err}"
    end
  end
end

