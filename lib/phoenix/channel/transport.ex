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
  def dispatch(%Message{topic: "phoenix", event: "heartbeat"}, sockets, adapter_pid, _router, _pubsub_server, _transport) do
    send adapter_pid, {:socket_reply, %Message{topic: "phoenix", event: "heartbeat", payload: %{}}}
    {:ok, sockets}
  end
  def dispatch(msg = %Message{event: "join"}, sockets, adapter_pid, router, pubsub_server, transport) do
    case router.channel_for_topic(msg.topic, transport) do
      nil ->
        Logger.debug fn -> "Ignoring unmatched topic \"#{msg.topic}\" in #{inspect(router)}" end
        transport_response({:ok, :undefined}, msg.topic, sockets)
      channel ->
        %Socket{pid: adapter_pid,
                router: router,
                pubsub_server: pubsub_server,
                topic: msg.topic,
                transport: transport}
        |> Socket.Supervisor.start_child(channel, msg.topic, msg.payload)
        |> handle_result("join")
        |> transport_response(msg.topic, sockets)
        |> log_error(router, msg.topic)
    end
  end
  def dispatch(msg = %Message{}, sockets, _adapter_pid, router, _pubsub_server, _transport) do
    sockets
    |> HashDict.get(msg.topic)
    |> dispatch(msg.topic, msg.event, msg.payload)
    |> transport_response(msg.topic, sockets)
    |> log_error(router, msg.topic)
  end
  defp transport_response({:ok, :undefined}, _topic, sockets) do
    {:ok, sockets}
  end
  defp transport_response({:ok, socket}, topic, sockets) do
    {:ok, HashDict.put(sockets, topic, socket)}
  end
  defp transport_response({:leave, socket}, topic, sockets) do
    Socket.Supervisor.terminate_child(socket)
    {:ok, HashDict.delete(sockets, topic)}
  end
  defp transport_response({:heartbeat, _socket}, _topic, sockets) do
    {:ok, sockets}
  end
  defp transport_response({:error, {reason, socket}}, topic, sockets) do
    Socket.Supervisor.terminate_child(socket)
    {:error, reason, HashDict.delete(sockets, topic)}
  end


  defp log_error({:error, reason, _sockets} = err, router, topic) do
    Logger.error fn ->
      """
      Crashed dispatching topic \"#{inspect topic}\"
        Reason: #{inspect(reason)}
        Router: #{inspect(router)}
      """
    end
    err
  end
  defp log_error(no_error, _router, _topic), do: no_error


  @doc """
  Dispatches `%Phoenix.Socket.Message{}` in response to a heartbeat message sent from the client.

  The Message format sent to phoenix requires the following key / values:

    * topic - The String value "phoenix"
    * event - The String value "heartbeat"
    * payload - An empty JSON message payload, ie {}

  The server will respond to heartbeats with the same message
  """
  def dispatch(nil, _topic, event, _msg) do
    handle_result({:error, {:unauthenticated, :undefined}}, event)
  end
  def dispatch(socket, _topic, "join", _msg) do
    handle_result({:error, {:invalid_method_call, socket}}, "join")
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

  defp handle_result({:ok, socket}, "leave") do
    :ok = Socket.Server.do_leave(socket)
    {:leave, socket}
  end
  defp handle_result({:ok, socket}, _event) do
    {:ok, socket}
  end
  defp handle_result({:leave, socket}, event)
    when not event in ["join", "leave"] do
    socket
    |> Socket.Server.dispatch_leave(%{reason: :leave})
    |> handle_result("leave")
  end
  defp handle_result({:error, {{:invalid_return, bad_return}, _socket}}, event) when event == "join"  do
    raise InvalidReturn, message: """
      expected `join` to return `{:ok, %Socket{}} | :ignore | {:error, reason, socket}` got `#{inspect bad_return}`
    """
  end
  defp handle_result({:error, {{:invalid_return, bad_return}, _socket}}, event) when event == "leave" do
    raise InvalidReturn, message: """
      expected `leave` to return `{:ok, socket_pid} | {:error, reason, socket_pid}` got `#{inspect bad_return}`
    """
  end
  defp handle_result({:error, {_reason, _socket}} = err, _event), do: err
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
        |> transport_response(topic, sockets)
        |> log_error(:norouter, topic)
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
