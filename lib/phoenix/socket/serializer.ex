defmodule Phoenix.Socket.Serializer do
  @moduledoc """
  A behaviour that serializes incoming and outgoing socket messages.

  By default Phoenix provides `Phoenix.Socket.V2.JSONSerializer` that
  encodes to JSON and decodes JSON messages.

  Custom serializers may be configured in the socket.
  """

  @doc """
  Encodes a `Phoenix.Socket.Broadcast` struct to fastlane format.
  """
  @callback fastlane!(Phoenix.Socket.Broadcast.t()) ::
              {:socket_push, :text, String.t()}
              | {:socket_push, :binary, binary()}

  @doc """
  Encodes `Phoenix.Socket.Message` and `Phoenix.Socket.Reply` structs to push format.
  """
  @callback encode!(Phoenix.Socket.Message.t() | Phoenix.Socket.Reply.t()) ::
              {:socket_push, :text, String.t()}
              | {:socket_push, :binary, binary()}

  @doc """
  Decodes iodata into `Phoenix.Socket.Message` struct.
  """
  @callback decode!(iodata, options :: Keyword.t()) :: Phoenix.Socket.Message.t()
end
