defmodule Phoenix.Channel.Transport do
  alias Phoenix.Socket
  alias Phoenix.Channel
  alias Phoenix.Socket.Message

  @moduledoc """
  The Transport Layer handles dispatching incoming and outgoing Channel
  `%Message{}`'s from remote clients, backed by different Channel transport
  implementations and serializations.

  ## The Transport Adapter Contract

  ### Server

  To implement a Transport adapter, the Server must broker the following actions:

    * Handle receiving incoming, encoded `%Message{}`'s from remote clients, then
      deserialing and fowarding message through `Transport.dispatch/2`. Finish by
      keeping state of returned `%Socket{}`.
    * Handle receiving outgoing `%Message{}`s as Elixir process messages, then
      encoding and fowarding to connected remote client.
    * Handle receiving arbitrary Elixir messages and fowarding through
      `Transport.dispatch_info/2`. Finish by keeping state of returned `%Socket{}`.
    * Handle remote client disconnects and relaying event through
      `Transport.dispatch_leave/2`

  See `Phoenix.Transports.WebSocket` for an example transport server implementation.


  ### Remote Client

  Phoenix includes a JavaScript client for WebSocket and Longpolling support using JSON
  encodings.

  However, a client can be implemented for other protocols and encodings by
  abiding by the `%Message{}` protocol as explained in `Phoenix.Message` docs.

  See `assets/cs/phoenix.coffee` for an example transport client implementation.
  """

  defmodule InvalidReturn do
    defexception [:message]
    def exception(msg) do
      %InvalidReturn{message: "Invalid Handler return: #{inspect msg}"}
    end
  end


  @doc """
  Dispatches `%Message{}` to Channel. All serialized, remote client messages
  should be deserialied and fowarded through this function by adapters.

  The following return signatures must be handled by transport adapters:
    * `{:ok, socket}` - Successful dispatch, with updated state
    * `{:error, socket, reason}` - Failed dispatched with updatd state

  The returned `%Socket{}`'s state must be held by the adapter
  """
  def dispatch(msg, socket) do
    socket
    |> Socket.set_current_channel(msg.channel, msg.topic)
    |> dispatch(msg.channel, msg.event, msg.message)
  end

  defp dispatch(socket, "phoenix", "heartbeat", _msg) do
    msg = %Message{channel: "phoenix", topic: "conn", event: "heartbeat", message: %{}}
    send socket.pid, msg

    {:ok, socket}
  end
  defp dispatch(socket, channel, "join", msg) do
    socket
    |> socket.router.match(:socket, channel, "join", msg)
    |> handle_result("join")
  end
  defp dispatch(socket, channel, event, msg) do
    if Socket.authenticated?(socket, channel, socket.topic) do
      socket
      |> socket.router.match(:socket, channel, event, msg)
      |> handle_result(event)
    else
      handle_result({:error, socket, :unauthenticated}, event)
    end
  end

  defp handle_result({:ok, socket}, "join") do
    {:ok, Channel.subscribe(socket, socket.channel, socket.topic)}
  end
  defp handle_result(socket = %Socket{}, "leave") do
    {:ok, Channel.unsubscribe(socket, socket.channel, socket.topic)}
  end
  defp handle_result(socket = %Socket{}, _event) do
    {:ok, socket}
  end
  defp handle_result({:error, socket, reason}, _event) do
    {:error, socket, reason}
  end
  defp handle_result(bad_return, event) when event in ["join", "leave"] do
    raise InvalidReturn, message: """
      expected {:ok, %Socket{}} | {:error, %Socket{}, reason} got #{inspect bad_return}
    """
  end
  defp handle_result(bad_return, _event) do
    raise InvalidReturn, message: """
      expected %Socket{} got #{inspect bad_return}
    """
  end

  @doc """
  Arbitrary Elixir processes are received by adapters and forwarded through
  this function to be dispatched as `"info"` events on each socket channel.

  The returned `%Socket{}`'s state must be held by the adapter
  """
  def dispatch_info(socket = %Socket{},  data) do
    socket = Enum.reduce socket.channels, socket, fn {channel, topic}, socket ->
      {:ok, socket} = dispatch_info(socket, channel, topic, data)
      socket
    end
    {:ok, socket}
  end
  def dispatch_info(socket, channel, topic, data) do
    socket
    |> Socket.set_current_channel(channel, topic)
    |> socket.router.match(:socket, channel, "info", data)
    |> handle_result("info")
  end

  @doc """
  Whenever a remote client disconnects, the adapter must forward the event through
  this function to be dispatched as `"leave"` events on each socket channel.

  Most adapters shutdown after this dispatch as they client has disconnected
  """
  def dispatch_leave(socket, reason) do
    Enum.each socket.channels, fn {channel, topic} ->
      socket
      |> Socket.set_current_channel(channel, topic)
      |> socket.router.match(:socket, channel, "leave", reason: reason)
      |> handle_result("leave")
    end
    :ok
  end
end
