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

  @doc """
  Sets topic of socket.
  """
  def put_topic(socket, topic) do
    %Socket{socket | topic: topic}
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
    put_in socket.assigns[key], value
  end
end
