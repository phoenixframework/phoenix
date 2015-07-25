defmodule Phoenix.Transports.Fastlane do
  use Behaviour

  @moduledoc """
  Defines a Behaviour for Transport `Phoenix.Socket.Broadcast` fastlaning.
  """

  @doc "Encodes `Phoenix.Socket.Message` struct to transport respresentation."
  defcallback fastlane!(Phoenix.Socket.Broadcast.t) :: term
end
