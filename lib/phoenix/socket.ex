defmodule Phoenix.Socket do
  alias Phoenix.Socket

  @moduledoc """
  Holds state for multiplexed socket connections and Channel authorization
  """

  @derive [Access]
  defstruct conn: nil,
            pid: nil,
            channel: nil,
            router: nil,
            authorized: false,
            assigns: %{}


  @doc """
  Sets current channel of multiplexed socket connection
  """
  def set_current_channel(socket, channel) do
    %Socket{socket | channel: channel}
  end

  @doc """
  Adds authorized channel to Socket's channel list

  ## Examples

      iex> Socket.authorize(%Socket{}, "rooms:lobby")
      %Socket{channel: "rooms:lobby", authorized: true}

  """
  def authorize(socket, channel) do
    %Socket{socket | channel: channel, authorized: true}
  end

  @doc """
  Deauthorizes channel

  ## Examples

      iex> socket = Socket.authorize(%Socket{}, "rooms:lobby")
      %Socket{channel: "rooms:lobby", authorized: true}
      iex> Socket.deauthorize(socket)
      %Socket{channel: "rooms:lobby", authorized: false}

  """
  def deauthorize(socket) do
    %Socket{socket | authorized: false}
  end

  @doc """
  Checks if a given String channel is authorized for this Socket

  ## Examples

      iex> socket = %Socket{}
      iex> Socket.authorized?(socket, "rooms:lobby")
      false
      iex> socket = Socket.authorize(socket, "rooms:lobby")
      %Socket{channel: "rooms:lobby", authorized: true}
      iex> Socket.authorized?(socket, "rooms:lobby")
      true

  """
  def authorized?(socket, channel) do
    socket.authorized && socket.channel == channel
  end

  @doc """
  Adds key/value pair to ephemeral socket state

  ## Examples

      iex> socket = Socket.set_current_channel(%Socket{}, "rooms:lobby")
      %Socket{channel: "rooms:lobby"}
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
