defmodule Phoenix.Socket do
  alias Phoenix.Socket

  @moduledoc """
  Holds state for multiplexed socket connections and Channel authorization
  """

  @derive [Access]
  defstruct conn: nil,
            pid: nil,
            topic: nil,
            router: nil,
            authorized: false,
            assigns: %{}


  @doc """
  Sets current topic of multiplexed socket connection
  """
  def put_current_topic(socket, topic) do
    %Socket{socket | topic: topic}
  end

  @doc """
  Adds authorized topic to Socket's topic list

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

      iex> socket = Socket.put_current_topic(%Socket{}, "rooms:lobby")
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
