defmodule Phoenix.Socket do
  @moduledoc """
  Holds state for every channel, pointing to its transport,
  pubsub server and more.

  ## Socket Fields

  * `assigns` - The map of socket assigns, default: `%{}`
  * `channel` - The channel module where this socket originated
  * `channel_pid` - The channel pid
  * `endpoint` - The endpoint module where this socket originated
  * `joined` - If the socket has effectively joined the channel
  * `pubsub_server` - The registered name of the socket's PubSub server
  * `ref` - The latest ref sent by the client
  * `topic` - The string topic, ie `"rooms:123"`
  * `transport` - The socket's transport, ie: `Phoenix.Transports.WebSocket`
  * `transport_pid` - The pid of the socket's transport process
  """

  defmodule InvalidMessageError do
    @moduledoc """
    Raised when the socket message is invalid.
    """
    defexception [:message]
  end

  alias Phoenix.Socket

  @type t :: %Socket{assigns: %{},
                     channel: atom,
                     channel_pid: pid,
                     endpoint: atom,
                     joined: boolean,
                     pubsub_server: atom,
                     ref: term,
                     topic: String.t,
                     transport: atom,
                     vsn: String.t,
                     transport_pid: pid}

  defstruct assigns: %{},
            channel: nil,
            channel_pid: nil,
            endpoint: nil,
            joined: false,
            pubsub_server: nil,
            ref: nil,
            topic: nil,
            transport: nil,
            vsn: nil,
            transport_pid: nil
end

defmodule Phoenix.Socket.Message do
  @moduledoc """
  Defines a message dispatched over transport to channels and vice-versa.

  The message format requires the following keys:

    * `topic` - The string topic or topic:subtopic pair namespace, ie "messages", "messages:123"
    * `event`- The string event name, ie "phx_join"
    * `payload` - The message payload
    * `ref` - The unique string ref

  """

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

    * `topic` - The string topic or topic:subtopic pair namespace, ie "messages", "messages:123"
    * `status` - The reply status as an atom
    * `payload` - The reply payload
    * `ref` - The unique string ref

  """

  defstruct topic: nil, status: nil, payload: nil, ref: nil
end

defmodule Phoenix.Socket.Broadcast do
  @moduledoc """
  Defines a message sent from pubsub to channels and vice-versa.

  The message format requires the following keys:

    * `topic` - The string topic or topic:subtopic pair namespace, ie "messages", "messages:123"
    * `event`- The string event name, ie "phx_join"
    * `payload` - The message payload

  """

  defstruct topic: nil, event: nil, payload: nil
end
