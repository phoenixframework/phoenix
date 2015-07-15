defmodule Phoenix.Socket do
  @moduledoc ~S"""
  Holds state for every channel, pointing to its transport,
  pubsub server and more.

  ## Socket Fields

  * `id` - The string id of the socket
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

  ## Channels

  Channels allow you to route pubsub events to channel handlers in your application.
  By default, Phoenix supports both WebSocket and LongPoller transports.
  See the `Phoenix.Channel.Transport` documentation for more information on writing
  your own transports. Channels are defined within a socket handler, using the
  `channel/2` macro, as seen below.

  ## Socket Behaviour

  Socket handlers are mounted in Endpoints and must define two callbacks:

    * `connect/2` - receives the socket params and authenticates the connection.
      Often used to wire up default `%Phoenix.Socket{}` assigns
      for all channels.
    * `id/1` - receives the socket returned by `connect/2`, and returns the
      string id of this connection. Used for forcing a disconnect for
      connection and all child channels. For sockets requiring no
      authentication, `nil` can be returned.

  Callback examples:

      defmodule MyApp.UserSocket do
        use Phoenix.Socket

        channel "rooms:*", MyApp.RoomChannel

        def connect(params, socket) do
          {:ok, assign(socket, :user_id, params["user_id"])}
        end

        def id(socket), do: "users_socket:#{socket.assigns.user_id}"
      end

      ...
      # disconnect all user's socket connections and their multiplexed channels
      MyApp.Endpoint.broadcast("users_socket:" <> user.id, "disconnect")

  """

  use Behaviour
  alias Phoenix.Socket
  alias Phoenix.Socket.Helpers

  defcallback connect(params :: map, Socket.t) :: {:ok, Socket.t} | :error

  defcallback id(Socket.t) :: String.t | nil


  defmodule InvalidMessageError do
    @moduledoc """
    Raised when the socket message is invalid.
    """
    defexception [:message]
  end


  @type t :: %Socket{id: nil,
                     assigns: %{},
                     channel: atom,
                     channel_pid: pid,
                     endpoint: atom,
                     joined: boolean,
                     pubsub_server: atom,
                     ref: term,
                     topic: String.t,
                     transport: atom,
                     transport_pid: pid}

  defstruct id: nil,
            assigns: %{},
            channel: nil,
            channel_pid: nil,
            endpoint: nil,
            joined: false,
            pubsub_server: nil,
            ref: nil,
            topic: nil,
            transport: nil,
            transport_pid: nil


  defmacro __using__(_) do
    quote do
      @behaviour Phoenix.Socket
      import unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :phoenix_channels, accumulate: true)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    channels = env.module |> Module.get_attribute(:phoenix_channels) |> Helpers.defchannels()

    quote do
      unquote(channels)
    end
  end

  @doc """
  Adds key/value pair to socket assigns.

  ## Examples

      iex> socket.assigns[:token]
      nil
      iex> socket = assign(socket, :token, "bar")
      iex> socket.assigns[:token]
      "bar"

  """
  def assign(socket = %Socket{}, key, value) do
    update_in socket.assigns, &Map.put(&1, key, value)
  end

  @doc """
  Defines a channel matching the given topic and transports.

    * `topic_pattern` - The string pattern, ie "rooms:*", "users:*", "system"
    * `module` - The channel module handler, ie `MyApp.RoomChannel`
    * `opts` - The optional list of options, see below

  ## Options

    * `:via` - the transport adapters to accept on this channel.
      Defaults `[Phoenix.Transports.WebSocket, Phoenix.Transports.LongPoller]`

  ## Examples

      channel "topic1:*", MyChannel
      channel "topic2:*", MyChannel, via: [Phoenix.Transports.WebSocket]
      channel "topic",    MyChannel, via: [Phoenix.Transports.LongPoller]

  ## Topic Patterns

  The `channel` macro accepts topic patterns in two flavors. A splat argument
  can be provided as the last character to indicate a "topic:subtopic" match. If
  a plain string is provied, only that topic will match the channel handler.
  Most use-cases will use the "topic:*" pattern to allow more versatile topic
  scoping.

  See `Phoenix.Channel` for more information
  """
  defmacro channel(topic_pattern, module, opts \\ []) do
    quote do
      @phoenix_channels {unquote_splicing([topic_pattern, module, opts])}
    end
  end
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
