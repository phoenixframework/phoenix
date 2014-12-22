defmodule Phoenix.Channel.Transport do
  alias Phoenix.Socket
  alias Phoenix.Channel
  alias Phoenix.Socket.Message

  @moduledoc """
  Handles dispatching incoming and outgoing Channel messages

  ## The Transport Adapter Contract

  The Transport layer dispatches `%Phoenix.Socket.Message{}`'s from remote clients,
  backed by different Channel transport implementations and serializations.

  ### Server

  To implement a Transport adapter, the Server must broker the following actions:

    * Handle receiving incoming, encoded `%Phoenix.Socket.Message{}`'s from
      remote clients, then deserialing and fowarding message through
      `Phoenix.Transport.dispatch/2`. Finish by keeping state of returned
      HashDict of `%Phoenix.Socket{}`s.
    * Handle receiving outgoing `%Phoenix.Socket.Message{}`s as Elixir process
      messages, then encoding and fowarding to connected remote client.
    * Handle receiving arbitrary Elixir messages and fowarding through
      `Phoenix.Transport.dispatch_info/2`. Finish by keeping state of returned
      HashDict of `%Phoenix.Socket{}`s.
    * Handle remote client disconnects and relaying event through
      `Phoenix.Transport.dispatch_leave/2`

  See `Phoenix.Transports.WebSocket` for an example transport server implementation.


  ### Remote Client

  Phoenix includes a JavaScript client for WebSocket and Longpolling support using JSON
  encodings.

  However, a client can be implemented for other protocols and encodings by
  abiding by the `Phoenix.Socket.Message` format

  See `assets/cs/phoenix.coffee` for an example transport client implementation.
  """

  defmodule InvalidReturn do
    defexception [:message]
    def exception(msg) do
      %InvalidReturn{message: "Invalid Handler return: #{inspect msg}"}
    end
  end


  @doc """
  Dispatches `%Phoenix.Socket.Message{}` to Channel. All serialized, remote client messages
  should be deserialized and forwarded through this function by adapters.

  The following return signatures must be handled by transport adapters:
    * `{:ok, sockets}` - Successful dispatch, with updated `HashDict` of sockets
    * `{:error, sockets, reason}` - Failed dispatched with updatd `HashDict` of sockets

  The returned `HashDict` of `%Phoenix.Socket{}`s must be held by the adapter
  """
  def dispatch(msg = %Message{}, sockets, adapter_pid, router) do
    socket = %Socket{pid: adapter_pid, router: router, channel: msg.channel, topic: msg.topic}

    sockets
    |> HashDict.get({msg.channel, msg.topic}, socket)
    |> dispatch(msg.channel, msg.event, msg.message)
    |> case do
      {:ok, socket} ->
        {:ok, HashDict.put(sockets, {msg.channel, msg.topic}, socket)}
      {:heartbeat, _socket} ->
        {:ok, sockets}
      {:error, _socket, reason} ->
        {:error, sockets, reason}
    end
  end

  @doc """
  Dispatches `%Phoenix.Socket.Message{}` in response to a heartbeat message sent from the client.

  The Message format sent to phoenix requires the following key / values:

    * channel - The String value "phoenix"
    * topic - The String value "conn"
    * event - The String value "heartbeat"
    * message - An empty JSON message payload, ie {}

  The server will respond to heartbeats with the same message
  """
  def dispatch(socket, "phoenix", "heartbeat", _msg) do
    msg = %Message{channel: "phoenix", topic: "conn", event: "heartbeat", message: %{}}
    send socket.pid, msg

    {:heartbeat, socket}
  end
  def dispatch(socket, channel, "join", msg) do
    socket
    |> socket.router.match(:incoming_socket, channel, "join", msg)
    |> handle_result("join")
  end
  def dispatch(socket, channel, event, msg) do
    if Socket.authorized?(socket, channel, socket.topic) do
      socket
      |> socket.router.match(:incoming_socket, channel, event, msg)
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
  defp handle_result(bad_return, event) when event == "join" do
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
  When an Adapter receives `{:broadcast, %Message{}}`, it dispatches to this
  function with its socket state.

  The message is routed to the intended channel's outgoing/3 callback.
  """
  def dispatch_broadcast(sockets, %Message{event: event, message: payload} = msg) do
    sockets
    |> HashDict.get({msg.channel, msg.topic})
    |> case do
      nil    ->
        {:ok, sockets}
      socket ->
        {:ok, sock} =
          socket
          |> socket.router.match(:outgoing_socket, socket.channel, event, payload)
          |> handle_result(event)

        {:ok, HashDict.put(sockets, {sock.channel, sock.topic}, sock)}
    end
  end

  @doc """
  Arbitrary Elixir processes are received by adapters and forwarded through
  this function to be dispatched as `"info"` events on each socket channel.

  The returned `HashDict` of `%Phoenix.Socket{}`s must be held by the adapter
  """
  def dispatch_info(sockets, data) do
    sockets = Enum.reduce sockets, sockets, fn {_, socket}, sockets ->
      {:ok, socket} = dispatch_info(socket, socket.channel, data)
      HashDict.put(sockets, {socket.channel, socket.topic}, socket)
    end
    {:ok, sockets}
  end
  def dispatch_info(socket = %Socket{}, channel, data) do
    socket
    |> socket.router.match(:incoming_socket, channel, "info", data)
    |> handle_result("info")
  end

  @doc """
  Whenever a remote client disconnects, the adapter must forward the event through
  this function to be dispatched as `"leave"` events on each socket channel.

  Most adapters shutdown after this dispatch as they client has disconnected
  """
  def dispatch_leave(sockets, reason) do
    Enum.each sockets, fn {_, socket} ->
      socket
      |> socket.router.match(:incoming_socket, socket.channel, "leave", reason: reason)
      |> handle_result("leave")
    end
    :ok
  end
end
