defmodule Phoenix.Channel.Transport do

  require Logger
  alias Phoenix.Socket
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
      HashDict of `%Phoenix.Socket{}`s. Message keys must be deserialized as strings.
    * Handle receiving outgoing `{:socket_reply, %Phoenix.Socket.Message{}}` as
      Elixir process messages, then encoding and fowarding to remote client.
    * Handle receiving outgoing `{:socket_broadcast, %Phoenix.Socket.Message{}}` as
      Elixir process messages, then forwarding message through
      `Phoenix.Transport.dispatch_broadcast/2`. Finish by keeping state of returned
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
    * `{:error, reason, sockets}` - Failed dispatched with updatd `HashDict` of sockets

  The returned `HashDict` of `%Phoenix.Socket{}`s must be held by the adapter
  """
  def dispatch(msg = %Message{}, sockets, adapter_pid, router, pubsub_server, transport) do
    {:ok, socket} =
      case HashDict.fetch(sockets, msg.topic) do
        :error ->
          %Socket{pid: adapter_pid,
                  router: router,
                  pubsub_server: pubsub_server,
                  topic: msg.topic,
                  transport: transport} |> Socket.Supervisor.start_child
        sock -> sock
      end

    socket
    |> dispatch(msg.topic, msg.event, msg.payload)
    |> transport_response(msg.topic, socket, sockets)
  end
  defp transport_response({:ok, _socket}, topic, socket, sockets) do
    {:ok, HashDict.put(sockets, topic, socket)}
  end
  defp transport_response({:leave, _socket}, topic, socket, sockets) do
    Socket.Supervisor.terminate_child(socket)
    {:ok, HashDict.delete(sockets, topic)}
  end
  defp transport_response({:heartbeat, _socket}, _topic, _socket1, sockets) do
    {:ok, sockets}
  end
  defp transport_response(:ignore, _topic, socket, sockets) do
    Socket.Supervisor.terminate_child(socket)
    {:ok, sockets}
  end
  defp transport_response({:error, reason, _socket}, topic, socket, sockets) do
    Logger.error fn ->
      """
      Crashed dispatching topic \"#{inspect socket.topic}\" to #{inspect(socket.channel || socket.router)}
        Reason: #{inspect(reason)}
        Router: #{inspect(socket.router)}
        State:  #{inspect(socket)}
      """
    end
    Socket.Supervisor.terminate_child(socket)
    {:error, reason, HashDict.delete(sockets, topic)}
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
    socket
    |> Socket.Server.dispatch_reply(%Message{topic: "phoenix", event: "heartbeat", payload: %{}})

    {:heartbeat, socket}
  end
  def dispatch(socket, topic, "join", msg) do
    socket
    |> Socket.Server.dispatch_join(topic, msg)
    |> handle_result("join")
  end
  def dispatch(socket, topic, "leave", msg) do
    socket
    |> Socket.Server.dispatch_leave(topic, msg)
    |> handle_result("leave")
  end
  def dispatch(socket, topic, event, msg) do
    socket
    |> Socket.Server.dispatch_in(topic, event, msg)
    |> handle_result(event)
  end

  defp handle_result({:ok, socket}, "join") do
    :ok = Socket.Server.do_join(socket)
    {:ok, socket}
  end
  defp handle_result({:ok, socket}, "leave") do
    :ok = Socket.Server.do_leave(socket)
    {:leave, socket}
  end
  defp handle_result({:ok, socket}, _event) do
    {:ok, socket}
  end
  defp handle_result(:ignore, "join"), do: :ignore
  defp handle_result({:leave, socket}, event)
    when not event in ["join", "leave"] do
    socket
    |> Socket.Server.dispatch_leave(%{reason: :leave})
    |> handle_result("leave")
  end
  defp handle_result({:error, reason, socket}, _event) do
    {:error, reason, socket}
  end
  defp handle_result(bad_return, event) when event == "join" do
    raise InvalidReturn, message: """
      expected `join` to return `{:ok, socket_pid} | :ignore | {:error, reason, socket_pid}` got `#{inspect bad_return}`
    """
  end
  defp handle_result(bad_return, event) when event == "leave" do
    raise InvalidReturn, message: """
      expected `leave` to return `{:ok, socket_pid} | {:error, reason, socket_pid}` got `#{inspect bad_return}`
    """
  end
  defp handle_result(bad_return, event) do
    raise InvalidReturn, message: """
      expected `#{event}` to return `{:ok, socket_pid} | {:leave, socket_pid}  | {:error, reason, socket_pid}` got `#{inspect bad_return}`
    """
  end

  @doc """
  When an Adapter receives `{:socket_broadcast, %Message{}}`, it dispatches to this
  function with its socket state.

  The message is routed to the intended channel's outgoing/3 callback.
  """
  def dispatch_broadcast(sockets, %Message{topic: topic, event: event, payload: payload}) do
    sockets
    |> HashDict.get(topic)
    |> case do
      nil    ->
        {:ok, sockets}
      socket ->
        socket
        |> Socket.Server.dispatch_out(event, payload)
        |> handle_result(event)
        |> transport_response(topic, socket, sockets)
    end
  end

  @doc """
  Whenever a remote client disconnects, the adapter must forward the event through
  this function to be dispatched as `"leave"` events on each socket channel.

  Most adapters shutdown after this dispatch as they client has disconnected
  """
  def dispatch_leave(sockets, reason) do
    Enum.each sockets, fn {_, socket} ->
      {:leave, _socket} =
        socket
        |> Socket.Server.dispatch_leave(%{reason: reason})
        |> handle_result("leave")
    end
    :ok
  end
end
