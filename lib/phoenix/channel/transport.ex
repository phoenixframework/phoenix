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
      `Phoenix.Transport.dispatch/6`. Message keys must be deserialized as strings.
    * Handle receiving `{:ok, socket_pid}` results from Transport dispatch and storing a
      HashDict of a string topics to Pid matches, and Pid to String topic matches.
      The HashDict of topic => pids is dispatched through the transport layer's
      `Phoenix.Transport.dispatch/6`.
    * Handle receiving outgoing `%Phoenix.Socket.Message{}` and `%Phoenix.Socket.Reply{}` as
      Elixir process messages, then encoding and fowarding to remote client.
    * Trap exits and handle receiving `{:EXIT, socket_pid, reason}` messages
      and delete the entries from the kept HashDict of socket processes.
      When exits are received, the adapter transport must reply to their client
      with one of two messages:

        - for `:normal` exits and shutdowns, send a reply to the remote
          client of a message from `Transport.chan_close_message/1`
        - for abnormal exits, send a reply to the remote client of a message
          from `Transport.chan_error_message/1`


  See `Phoenix.Transports.WebSocket` for an example transport server implementation.


  ### Remote Client

  Synchronouse Replies and `ref`'s:

  Channels can reply, synchronously, to any `handle_in/3` event. To match pushes
  with replies, clients must include a unique `ref` with every message and the
  channel server will reply with a matching ref where the client and pick up the
  callback for the matching reply.

  Phoenix includes a JavaScript client for WebSocket and Longpolling support using JSON
  encodings.

  However, a client can be implemented for other protocols and encodings by
  abiding by the `Phoenix.Socket.Message` format

  See `web/static/js/phoenix.js` for an example transport client implementation.
  """

  @doc """
  Dispatches `%Phoenix.Socket.Message{}` to Channel. All serialized, remote client messages
  should be deserialized and forwarded through this function by adapters.

  The following return signatures must be handled by transport adapters:
    * `{:ok, socket_pid}` - Successful dispatch, with pid of new socket
    * `{:error, reason}` - Unauthorized or unmatched dispatch

  """
  def dispatch(%Message{} = msg, sockets, transport_pid, socket_handler, socket, endpoint, transport) do
    sockets
    |> HashDict.get(msg.topic)
    |> dispatch(msg, transport_pid, socket_handler, socket, endpoint, transport)
  end

  @doc """
  Dispatches `%Phoenix.Socket.Message{}` in response to a heartbeat message sent from the client.

  The Message format sent to phoenix requires the following key / values:

    * topic - The String value "phoenix"
    * event - The String value "heartbeat"
    * payload - An empty JSON message payload, ie {}

  The server will respond to heartbeats with the same message
  """
  def dispatch(_, %{ref: ref, topic: "phoenix", event: "heartbeat"}, transport_pid, _socket_handler, _socket, _pubsub_server, _transport) do
    reply(transport_pid, ref, "phoenix", %{status: :ok, response: %{}})
    :ok
  end
  def dispatch(nil, %{event: "phx_join"} = msg, transport_pid, socket_handler, base_socket, endpoint, transport) do
    case socket_handler.channel_for_topic(msg.topic, transport) do
      nil     -> log_ignore(msg.topic, socket_handler)
      channel ->
        socket = %Socket{transport_pid: transport_pid,
                  assigns: base_socket.assigns,
                  endpoint: endpoint,
                  pubsub_server: endpoint.__pubsub_server__(),
                  topic: msg.topic,
                  channel: channel,
                  transport: transport}

        log_info msg.topic, fn ->
          "JOIN #{msg.topic} to #{inspect(channel)}\n" <>
          "  Transport:  #{inspect transport}\n" <>
          "  Parameters: #{inspect msg.payload}"
        end

        case Phoenix.Channel.Server.join(socket, msg.payload) do
          {:ok, response, pid} ->
            log_info msg.topic, fn -> "Replied #{msg.topic} :ok" end

            reply(socket, msg.ref, %{status: :ok, response: response})
            {:ok, pid}
          {:error, response} ->
            log_info msg.topic, fn -> "Replied #{msg.topic} :error" end

            reply(socket, msg.ref, %{status: :error, response: response})
            {:error, response}
        end
    end
  end
  def dispatch(nil, msg, _transport_pid, socket_handler, _socket, _pubsub_server, _transport) do
    log_ignore(msg.topic, socket_handler)
  end
  def dispatch(socket_pid, %{event: "phx_leave", ref: ref}, _transport_pid, _socket_handler, _socket, _pubsub_server, _transport) do
    Phoenix.Channel.Server.leave(socket_pid, ref)
    :ok
  end
  def dispatch(socket_pid, msg, _transport_pid, _socket_handler, _socket, _pubsub_server, _transport) do
    send(socket_pid, msg)
    :ok
  end

  defp reply(%Socket{transport_pid: trans_pid, topic: topic}, ref, payload) do
    reply(trans_pid, ref, topic, payload)
  end
  defp reply(transport_pid, ref, topic, payload) when is_pid(transport_pid) do
    Phoenix.Channel.Server.reply transport_pid, ref, topic, payload
  end

  defp log_info("phoenix" <> _, _func), do: :noop
  defp log_info(_topic, func), do: Logger.info(func)

  defp log_ignore(topic, socket_handler) do
    Logger.debug fn -> "Ignoring unmatched topic \"#{topic}\" in #{inspect(socket_handler)}" end
    {:error, %{reason: "unmatched topic"}}
  end

  @doc """
  Returns the `%Phoenix.Message{}` for a channel close event
  """
  def chan_close_message(topic) do
    %Message{topic: topic, event: "phx_close", payload: %{}}
  end

  @doc """
  Returns the `%Phoenix.Message{}` for a channel error event
  """
  def chan_error_message(topic) do
    %Message{topic: topic, event: "phx_error", payload: %{}}
  end

  @doc """
  Checks the Origin request header against the list of allowed origins
  configured on the `Phoenix.Endpoint` `:transports` config. If the Origin
  header matches the allowed origins, no Origin header was sent or no origins
  configured it will return the given `Plug.Conn`. Otherwise a 403 Forbidden
  response will be send and the connection halted.
  """
  def check_origin(conn, opts \\ []) do
    import Plug.Conn

    endpoint = Phoenix.Controller.endpoint_module(conn)
    allowed_origins = Dict.get(endpoint.config(:transports), :origins)
    origin = get_req_header(conn, "origin") |> List.first

    send = opts[:send] || &send_resp(&1)

    if origin_allowed?(origin, allowed_origins) do
      conn
    else
      resp(conn, :forbidden, "")
      |> send.()
      |> halt
    end
  end

  defp origin_allowed?(nil, _) do
    true
  end
  defp origin_allowed?(_, nil) do
    true
  end
  defp origin_allowed?(origin, allowed_origins) do
    origin = URI.parse(origin)

    Enum.any?(allowed_origins, fn allowed ->
      allowed = URI.parse(allowed)

      compare?(origin.scheme, allowed.scheme) and
      compare?(origin.port, allowed.port) and
      compare?(origin.host, allowed.host)
    end)
  end

  defp compare?(nil, _), do: true
  defp compare?(_, nil), do: true
  defp compare?(x, y),   do: x == y
end
