defmodule Phoenix.Socket do
  alias Phoenix.Socket

  @moduledoc """
  Holds state for multiplexed socket connections and Channel/Topic authorization
  """

  defstruct conn: nil,
            pid: nil,
            channel: nil,
            topic: nil,
            router: nil,
            channels: [],
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

      iex> Socket.add_channel(socket, "rooms", "lobby")

  """
  def add_channel(socket, channel, topic) do
    if authenticated?(socket, channel, topic) do
      socket
    else
      %Socket{socket | channels: [{channel, topic} | socket.channels]}
    end
  end

  @doc """
  Removes a channel/topic pair from authorized channels list

  ## Examples

      iex> Socket.delete_channel(socket, "rooms", "lobby")

  """
  def delete_channel(socket, channel, topic) do
    %Socket{socket | channels: List.delete(socket.channels, {channel, topic})}
  end

  @doc """
  Checks if a given String channel/topic pair is authorized for this Socket

  ## Examples

      iex> Socket.authenticated?(socket, "rooms", "lobby")
      true

  """
  def authenticated?(socket, channel, topic) do
    Enum.member? socket.channels, {channel, topic}
  end

  @doc """
  Adds key/value pair to ephemeral socket state
  """
  def assign(socket, key, value) do
    %Socket{socket | assigns: Map.put(socket.assigns, key, value)}
  end
end


