defmodule Phoenix.Socket do
  alias Phoenix.Socket

  @moduledoc """
  Holds state for multiplexed socket connections and Channel/Topic authorization
  """

  @derive [Access]
  defstruct conn: nil,
            pid: nil,
            channel: nil,
            topic: nil,
            router: nil,
            authorized: false,
            assigns: %{}


  @doc """
  Sets current channel of multiplexed socket connection
  """
  def set_current_channel(socket, channel, topic) do
    %Socket{socket | channel: channel, topic: topic}
  end

  @doc """
  Adds authorized channel/topic pair to Socket's channel list

  ## Examples

      iex> Socket.authorize(%Socket{}, "rooms", "lobby")
      %Socket{channel: "rooms", topic: "lobby", authorized: true}

  """
  def authorize(socket, channel, topic) do
    socket
    |> set_current_channel(channel, topic)
    |> put_in([:authorized], true)
  end

  @doc """
  Deauthorizes channel/topic pair

  ## Examples

      iex> socket = Socket.authorize(%Socket{}, "rooms", "lobby")
      %Socket{channel: "rooms", topic: "lobby", authorized: true}
      iex> Socket.deauthorize(socket)
      %Socket{channel: "rooms", topic: "lobby", authorized: false}

  """
  def deauthorize(socket) do
    socket
    |> put_in([:authorized], false)
  end

  @doc """
  Checks if a given String channel/topic pair is authorized for this Socket

  ## Examples

      iex> socket = %Socket{}
      iex> Socket.authorized?(socket, "rooms", "lobby")
      false
      iex> socket = Socket.authorize(socket, "rooms", "lobby")
      %Socket{channel: "rooms", topic: "lobby", authorized: true}
      iex> Socket.authorized?(socket, "rooms", "lobby")
      true

  """
  def authorized?(socket, channel, topic) do
    socket.authorized && socket.channel == channel && socket.topic == topic
  end

  @doc """
  Returns the value for the given assign key, scoped to the active multiplexed
  channel/topic pair or for a specific channel/topic

  ## Examples

      iex> socket = Socket.set_current_channel(%Socket{}, "rooms", "lobby")
      %Socket{channel: "rooms", topic: "lobby"}
      iex> Socket.get_assign(socket, :token)
      nil
      iex> socket = Socket.assign(socket, :token, "bar")
      iex> Socket.get_assign(socket, :token)
      "bar"

  """
  def get_assign(socket = %Socket{}, key) do
    get_in socket.assigns, [key]
  end

  @doc """
  Adds key/value pair to ephemeral socket state

  ## Examples

      iex> socket = Socket.set_current_channel(%Socket{}, "rooms", "lobby")
      %Socket{channel: "rooms", topic: "lobby"}
      iex> Socket.get_assign(socket, :token)
      nil
      iex> socket = Socket.assign(socket, :token, "bar")
      iex> Socket.get_assign(socket, :token)
      "bar"

  """
  def assign(socket = %Socket{}, key, value) do
    put_in socket, [:assigns, key], value
  end
end


