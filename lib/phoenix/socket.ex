defmodule Phoenix.Socket do

  @moduledoc """
  Holds state for multiplexed socket connections and Channel authorization

  ## Socket Fields

  * `transport_pid` - The Pid of the socket's transport process
  * `topic` - The string topic, ie `"rooms:123"`
  * `router` - The router module where this socket originated
  * `endpoint` - The endpoint module where this socket originated
  * `channel` - The channel module where this socket originated
  * `authorized` - The boolean authorization status, default `false`
  * `assigns` - The map of socket assigns, default: `%{}`
  * `transport` - The socket's Transport, ie: `Phoenix.Transports.WebSocket`
  * `pubsub_server` - The registered name of the socket's PubSub server
  * `ref` - The latest ref sent by the client


  """

  alias Phoenix.Socket

  defstruct transport_pid: nil,
            topic: nil,
            router: nil,
            endpoint: nil,
            channel: nil,
            authorized: false,
            transport: nil,
            pubsub_server: nil,
            ref: nil,
            joined: false,
            assigns: %{}


  @doc """
  Sets topic of socket
  """
  def put_topic(socket, topic) do
    %Socket{socket | topic: topic}
  end

  @doc """
  Sets channel of socket
  """
  def put_channel(socket, channel) do
    %Socket{socket | channel: channel}
  end

  @doc """
  Authorizes socket's topic

  ## Examples

      iex> Socket.authorize(%Socket{}, "rooms:lobby")
      %Socket{topic: "rooms:lobby", authorized: true}

  """
  def authorize(socket, topic) do
    %Socket{socket | topic: topic, authorized: true}
  end

  @doc """
  Deauthorizes topic

  ## Examples

      iex> socket = Socket.authorize(%Socket{}, "rooms:lobby")
      %Socket{topic: "rooms:lobby", authorized: true}
      iex> Socket.deauthorize(socket)
      %Socket{topic: "rooms:lobby", authorized: false}

  """
  def deauthorize(socket) do
    %Socket{socket | authorized: false}
  end

  @doc """
  Checks if a given String topic is authorized for this Socket

  ## Examples

      iex> socket = %Socket{}
      iex> Socket.authorized?(socket, "rooms:lobby")
      false
      iex> socket = Socket.authorize(socket, "rooms:lobby")
      %Socket{topic: "rooms:lobby", authorized: true}
      iex> Socket.authorized?(socket, "rooms:lobby")
      true

  """
  def authorized?(socket, topic) do
    socket.authorized && socket.topic == topic
  end

  @doc """
  Adds key/value pair to ephemeral socket state

  ## Examples

      iex> socket = Socket.put_topic(%Socket{}, "rooms:lobby")
      %Socket{topic: "rooms:lobby"}
      iex> socket.assigns[:token]
      nil
      iex> socket = Socket.assign(socket, :token, "bar")
      iex> socket.assigns[:token]
      "bar"

  """
  def assign(socket = %Socket{}, key, value) do
    put_in socket.assigns[key], value
  end
end
