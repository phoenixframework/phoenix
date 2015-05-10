defmodule Phoenix.Socket do
  @moduledoc """
  Holds state for every channel pointing to its transport.

  ## Socket Fields

  * `assigns` - The map of socket assigns, default: `%{}`
  * `channel` - The channel module where this socket originated
  * `endpoint` - The endpoint module where this socket originated
  * `joined` - If the socket has effectively joined the channel
  * `pubsub_server` - The registered name of the socket's PubSub server
  * `ref` - The latest ref sent by the client
  * `topic` - The string topic, ie `"rooms:123"`
  * `transport` - The socket's transport, ie: `Phoenix.Transports.WebSocket`
  * `transport_pid` - The pid of the socket's transport process
  """

  alias Phoenix.Socket

  @type t :: %Socket{assigns: %{},
                     channel: atom,
                     endpoint: atom,
                     joined: boolean,
                     pubsub_server: atom,
                     ref: String.t,
                     topic: String.t,
                     transport: atom,
                     transport_pid: pid}

  defstruct assigns: %{},
            channel: nil,
            endpoint: nil,
            joined: false,
            pubsub_server: nil,
            ref: nil,
            topic: nil,
            transport: nil,
            transport_pid: nil
end

defmodule Phoenix.Socket.Message do
  @moduledoc """
  Defines a `Phoenix.Socket` message dispatched over channels.

  The message format requires the following keys:

    * `topic` - The string topic or topic:subtopic pair namespace, ie "messages", "messages:123"
    * `event`- The string event name, ie "phx_join"
    * `payload` - The message payload
    * `ref` - The unique string ref

  """

  alias Phoenix.Socket.Message

  defstruct topic: nil, event: nil, payload: nil, ref: nil

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
        event: Map.fetch!(map, "event"),
        payload: Map.fetch!(map, "payload"),
        ref: Map.fetch!(map, "ref")
      }
    rescue
      err in [KeyError] -> raise InvalidMessage, message: "Missing key: '#{err.key}'"
    end
  end
end

defmodule Phoenix.Socket.Reply do
  @moduledoc """
  Defines a `Phoenix.Socket.Reply` message dispatched over channels.

  The message format requires the following keys:

    * `topic` - The string topic or topic:subtopic pair namespace, ie "messages", "messages:123"
    * `status` - The reply status as an atom
    * `payload` - The reply payload
    * `ref` - The unique string ref

  """

  defstruct topic: nil, status: nil, payload: nil, ref: nil
end
