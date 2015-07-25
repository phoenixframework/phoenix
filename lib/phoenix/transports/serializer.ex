defmodule Phoenix.Transports.Serializer do
  use Behaviour

  @moduledoc """
  Defines a Behaviour for Transport `Phoenix.Socket.Message` serializiation.
  """

  @doc "Translates a `Phoenix.Socket.Broadcast` struct to fastlane format."
  defcallback fastlane!(Phoenix.Socket.Broadcast.t) :: term

  @doc "Encodes `Phoenix.Socket.Message` struct to transport respresentation."
  defcallback encode!(Phoenix.Socket.Message.t | Phoenix.Socket.Reply.t) :: term

  @doc "Decodes iodata into `Phoenix.Socket.Message` struct."
  defcallback decode!(iodata, options :: Keyword.t) :: Phoenix.Socket.Message.t
end
