defmodule Phoenix.Transports.Serializer do
  use Behaviour

  @moduledoc """
  Defines a Behaviour for Transport `Phoenix.Socket.Message` serializiation
  """

  @doc "Encodes `Phoenix.Socket.Message` struct to iodata"
  defcallback encode!(Phoenix.Socket.Message.t) :: {:text | :binary, iodata}

  @doc "Decodes iodata into `Phoenix.Socket.Message` struct"
  defcallback decode!(iodata, :text | :binary) :: Phoenix.Socket.Message.t
end
