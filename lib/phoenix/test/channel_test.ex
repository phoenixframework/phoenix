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

  @doc """
  Pushes a message into the channel.

  The triggers the `handle_in/3` callback in the channel.
  """
  def push(pid, event, payload \\ %{}) do
    ref = make_ref()
    Phoenix.Channel.Server.push(pid, event, ref, payload)
    ref
  end

  @doc """
  Asserts the channel has pushed a message back to the client
  with the given event and payload under `timeout`.

  Notice event and payload are patterns. This means one can write:

      assert_pushed "some_event", %{"data" => _}

  In the assertion above, we don't particularly care about
  the data being sent, as long as something was sent.

  The timeout is in miliseconds and defaults to 100ms.
  """
  defmacro assert_pushed(event, payload, timeout \\ 100) do
    quote do
      assert_receive %Phoenix.Socket.Message{event: unquote(event),
                                             payload: unquote(payload)}, unquote(timeout)
    end
  end

  @doc """
  Asserts the channel has replies to the given message within
  `timeout`.

  Notice status and payload are patterns. This means one can write:

      ref = push channel, "some_event"
      assert_replied ref, :ok, %{"data" => _}

  In the assertion above, we don't particularly care about
  the data being sent, as long as something was replied.

  The timeout is in miliseconds and defaults to 100ms.
  """
  defmacro assert_replied(ref, status, payload, timeout \\ 100) do
    quote do
      ref = unquote(ref)
      assert_receive %Phoenix.Socket.Reply{status: unquote(status), ref: ^ref,
                                           payload: unquote(payload)}, unquote(timeout)
    end
  end
end
