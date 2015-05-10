defmodule Phoenix.ChannelTest do
  @moduledoc """
  Conveniences for testing Phoenix channels.

  In channel tests, we interact with channels via process
  communication, sending messages and receiving replies.
  """

  alias Phoenix.Socket

  @doc false
  defmacro __using__(_) do
    quote do
      import Phoenix.ChannelTest
    end
  end

  @doc """
  Joins the channel under the given topic and payload.

  The given channel is joined in a separate process
  which is linked to the test process.

  The endpoint is read from the `@endpoint` variable.
  """
  defmacro join(channel, topic, payload \\ Macro.escape(%{})) do
    quote do
      join(@endpoint, unquote(channel), unquote(topic), unquote(payload))
    end
  end

  @doc """
  Joins the channel powered by the pubsub server in
  endpoint under the given topic and payload.

  This is useful when you need to join a channel in
  different enpoints, in practice, `join/3` is recommended.
  """
  def join(endpoint, channel, topic, payload) do
    unless endpoint do
      raise "module attribute @endpoint not set for join/3"
    end

    socket = %Socket{transport_pid: self(),
                     endpoint: endpoint,
                     pubsub_server: endpoint.__pubsub_server__(),
                     topic: topic,
                     ref: make_ref(),
                     channel: channel,
                     transport: __MODULE__}
    Phoenix.Channel.Server.join(socket, payload)
  end
end
