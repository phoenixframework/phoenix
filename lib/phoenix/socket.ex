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

      iex> Socket.add_channel(%Socket{channels: []}, "rooms", "lobby")
      %Socket{channels: [{"rooms", "lobby"}]}

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

      iex> socket = Socket.add_channel(%Socket{channels: []}, "rooms", "lobby")
      %Socket{channels: [{"rooms", "lobby"}]}
      iex> Socket.delete_channel(socket, "rooms", "lobby")
      %Socket{channels: []}

  """
  def delete_channel(socket, channel, topic) do
    %Socket{socket | channels: List.delete(socket.channels, {channel, topic})}
  end

  @doc """
  Checks if a given String channel/topic pair is authorized for this Socket

  ## Examples

      iex> socket = %Socket{}
      iex> Socket.authenticated?(socket, "rooms", "lobby")
      false
      iex> socket = Socket.add_channel(socket, "rooms", "lobby")
      %Socket{channels: [{"rooms", "lobby"}]}
      iex> Socket.authenticated?(socket, "rooms", "lobby")
      true

  """
  def authenticated?(socket, channel, topic) do
    Enum.member? socket.channels, {channel, topic}
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
      iex> Socket.get_assign(socket, "rooms", "lobby", :token)
      "bar"

  """
  def get_assign(socket = %Socket{channel: channel, topic: topic}, key) do
    get_assign socket, channel, topic, key
  end
  def get_assign(socket, channel, topic, key) do
    get_in socket, [:assigns, channel, topic, key]
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
      iex> Socket.get_assign(socket, "rooms", "lobby", :token)
      "bar"

  """
  def assign(socket = %Socket{channel: channel, topic: topic}, key, value) do
    assign socket, channel, topic, key, value
  end
  def assign(socket, channel, topic, key, value) do
    socket
    |> ensure_defaults(channel, topic)
    |> put_in([:assigns, channel, topic, key], value)
  end
  defp ensure_defaults(socket, channel, topic) do
    socket
    |> update_in([:assigns, channel], fn val -> val || %{} end)
    |> update_in([:assigns, channel, topic], fn val -> val || %{} end)
  end
end


