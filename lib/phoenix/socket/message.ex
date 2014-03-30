defmodule Phoenix.Socket.Message do
  alias Phoenix.Socket.Message

  defstruct channel: nil, event: nil, message: nil

  def parse!(text) do
    case JSON.decode(text) do
      {:ok, json} ->
        %Message{
          channel: Dict.fetch!(json, "channel"),
          event:   Dict.fetch!(json, "event"),
          message: Dict.fetch!(json, "message")
        }
      {:error, reason} -> raise reason
    end
  end
end
