defmodule Phoenix.Transports.Serializer do
  @moduledoc """
  Defines a behaviour for `Phoenix.Socket.Message` serialization.
  """

  @doc "Translates a `Phoenix.Socket.Broadcast` struct to fastlane format"
  @callback fastlane!(Phoenix.Socket.Broadcast.t) :: term

  @doc "Encodes `Phoenix.Socket.Message` struct to transport respresentation"
  @callback encode!(Phoenix.Socket.Message.t | Phoenix.Socket.Reply.t) :: term

  @doc "Decodes iodata into `Phoenix.Socket.Message` struct"
  @callback decode!(iodata, options :: Keyword.t) :: Phoenix.Socket.Message.t
end
