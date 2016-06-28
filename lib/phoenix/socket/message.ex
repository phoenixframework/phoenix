defmodule Phoenix.Socket.Message do
  @moduledoc """
  Defines a message dispatched over transport to channels and vice-versa.

  The message format requires the following keys:

    * `topic` - The string topic or topic:subtopic pair namespace, for
      example "messages", "messages:123"
    * `event`- The string event name, for example "phx_join"
    * `payload` - The message payload
    * `ref` - The unique string ref
  """

  @type t :: %Phoenix.Socket.Message{}
  defstruct topic: nil, event: nil, payload: nil, ref: nil

  @doc """
  Converts a map with string keys into a message struct.

  Raises `Phoenix.Socket.InvalidMessageError` if not valid.
  """
  def from_map!(map) when is_map(map) do
    try do
      %Phoenix.Socket.Message{
        topic: Map.fetch!(map, "topic"),
        event: Map.fetch!(map, "event"),
        payload: Map.fetch!(map, "payload"),
        ref: Map.fetch!(map, "ref")
      }
    rescue
      err in [KeyError] ->
        raise Phoenix.Socket.InvalidMessageError, message: "missing key #{inspect err.key}"
    end
  end
end

defmodule Phoenix.Socket.Reply do
  @moduledoc """
  Defines a reply sent from channels to transports.

  The message format requires the following keys:

    * `topic` - The string topic or topic:subtopic pair namespace, for example "messages", "messages:123"
    * `status` - The reply status as an atom
    * `payload` - The reply payload
    * `ref` - The unique string ref

  """

  @type t :: %Phoenix.Socket.Reply{}
  defstruct topic: nil, status: nil, payload: nil, ref: nil
end

defmodule Phoenix.Socket.Broadcast do
  @moduledoc """
  Defines a message sent from pubsub to channels and vice-versa.

  The message format requires the following keys:

    * `topic` - The string topic or topic:subtopic pair namespace, for example "messages", "messages:123"
    * `event`- The string event name, for example "phx_join"
    * `payload` - The message payload

  """

  @type t :: %Phoenix.Socket.Broadcast{}
  defstruct topic: nil, event: nil, payload: nil
end
