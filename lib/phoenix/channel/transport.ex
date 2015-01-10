defmodule Phoenix.Channel.Transport do
  alias Phoenix.Socket
  alias Phoenix.Socket.Message
  alias Phoenix.PubSub

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
    * Handle receiving outgoing `{:socket_reply, %Phoenix.Socket.Message{}}` as
      Elixir process messages, then encoding and fowarding to remote client.
    * Handle receiving outgoing `{:socket_broadcast, %Phoenix.Socket.Message{}}` as
      Elixir process messages, then forwarding message through
      `Phoenix.Transport.dispatch_broadcast/2`. Finish by keeping state of returned
      HashDict of `%Phoenix.Socket{}`s.
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
  def dispatch(msg = %Message{}, sockets, adapter_pid, router, transport) do
    socket = %Socket{pid: adapter_pid, router: router, topic: msg.topic, transport: transport}

    sockets
    |> HashDict.get(msg.topic, socket)
    |> dispatch(msg.topic, msg.event, msg.payload)
    |> transport_response(sockets)
  end
  defp transport_response({:ok, socket}, sockets) do
    {:ok, HashDict.put(sockets, socket.topic, socket)}
  end
  defp transport_response({:leave, socket}, sockets) do
    {:ok, HashDict.delete(sockets, socket.topic)}
  end
  defp transport_response({:heartbeat, _socket}, sockets) do
    {:ok, sockets}
  end
  defp transport_response({:error, socket, reason}, sockets) do
    {:error, HashDict.delete(sockets, socket.topic), reason}
  end


  @doc """
  Dispatches `%Phoenix.Socket.Message{}` in response to a heartbeat message sent from the client.

  The Message format sent to phoenix requires the following key / values:

    * topic - The String value "phoenix"
    * event - The String value "heartbeat"
    * payload - An empty JSON message payload, ie {}

  The server will respond to heartbeats with the same message
  """
  def dispatch(socket, "phoenix", "heartbeat", _msg) do
    send socket.pid, {:socket_reply, %Message{topic: "phoenix", event: "heartbeat", payload: %{}}}

    {:heartbeat, socket}
  end
  def dispatch(socket, topic, "join", msg) do
    socket
    |> socket.router.match_channel(:incoming, topic, "join", msg, socket.transport)
    |> handle_result("join")
  end
  def dispatch(socket, topic, event, msg) do
    if Socket.authorized?(socket, topic) do
      socket
      |> socket.router.match_channel(:incoming, topic, event, msg, socket.transport)
      |> handle_result(event)
    else
      handle_result({:error, socket, :unauthenticated}, event)
    end
  end

  defp handle_result({:ok, socket = %Socket{}}, "join") do
    PubSub.subscribe(socket.pid, socket.topic)
    {:ok, Socket.authorize(socket, socket.topic)}
  end
  defp handle_result({:ok, socket = %Socket{}}, "leave") do
    PubSub.unsubscribe(socket.pid, socket.topic)
    {:leave, Socket.deauthorize(socket)}
  end
  defp handle_result({:ok, socket = %Socket{}}, _event) do
    {:ok, socket}
  end
  defp handle_result({:leave, socket = %Socket{}}, event)
    when not event in ["join", "leave"] do

    socket
    |> socket.router.match_channel(:incoming, socket.topic, "leave", %{reason: :leave}, socket.transport)
    |> handle_result("leave")
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
      expected {:ok, %Socket{}} | {:leave, %Socket{}, reason} got #{inspect bad_return}
    """
  end

  @doc """
  When an Adapter receives `{:socket_broadcast, %Message{}}`, it dispatches to this
  function with its socket state.

  The message is routed to the intended channel's outgoing/3 callback.
  """
  def dispatch_broadcast(sockets, %Message{event: event, payload: payload} = msg) do
    sockets
    |> HashDict.get(msg.topic)
    |> case do
      nil    ->
        {:ok, sockets}
      socket ->
        socket
        |> socket.router.match_channel(:outgoing, socket.topic, event, payload, socket.transport)
        |> handle_result(event)
        |> transport_response(sockets)
    end
  end

  @doc """
  Arbitrary Elixir processes are received by adapters and forwarded through
  this function to be dispatched as `"info"` events on each socket channel.

  The returned `HashDict` of `%Phoenix.Socket{}`s must be held by the adapter
  """
  def dispatch_info(sockets, data) do
    sockets = Enum.reduce sockets, sockets, fn {_, socket}, sockets ->
      socket
      |> do_dispatch_info(data)
      |> transport_response(sockets)
      |> case do
       {:ok, sockets}             -> sockets
       {:error, sockets, _reason} -> sockets
      end
    end

    {:ok, sockets}
  end
  defp do_dispatch_info(%Socket{topic: topic, transport: transport} = socket, data) do
    socket
    |> socket.router.match_channel(:info, topic, "info", data, transport)
    |> handle_result("info")
  end

  @doc """
  Whenever a remote client disconnects, the adapter must forward the event through
  this function to be dispatched as `"leave"` events on each socket channel.

  Most adapters shutdown after this dispatch as they client has disconnected
  """
  def dispatch_leave(sockets, reason) do
    Enum.each sockets, fn {_, %Socket{topic: topic, transport: trans} = socket} ->
      socket
      |> socket.router.match_channel(:incoming, topic, "leave", %{reason: reason}, trans)
      |> handle_result("leave")
    end
    :ok
  end
end
