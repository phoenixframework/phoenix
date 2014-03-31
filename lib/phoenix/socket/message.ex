defmodule Phoenix.Socket.Message do
  alias Phoenix.Socket.Message

  defstruct channel: nil, topic: nil, event: nil, message: nil

  @doc """
  Parse json message into required format, raise if invalid

  Messages require the following keys:
    * channel - The String Channel namespace, ie "messages"
    * event - The String event name, ie "join"
    * message - The String JSON message payload

  Returns The Message Map parsed from JSON
  """
  def parse!(text) do
    case JSON.decode(text) do
      {:ok, json} ->
        %Message{
          channel: Dict.fetch!(json, "channel"),
          topic:   Dict.fetch!(json, "topic"),
          event:   Dict.fetch!(json, "event"),
          message: Dict.fetch!(json, "message")
        }
      {:error, reason} -> raise reason
    end
  end
end
