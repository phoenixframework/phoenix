defmodule Phoenix.Transports.Serializer do
  use Behaviour

  @moduledoc """
  Defines a Behaviour for Transport `Phoenix.Socket.Message` serializiation
  """

  @doc "Encodes `Phoenix.Socket.Message` struct to binary"
  defcallback encode!(Phoenix.Socket.Message.t) :: binary

  @doc "Decodes binary into `Phoenix.Socket.Message` struct"
  defcallback decode!(binary) :: Phoenix.Socket.Message.t
end
