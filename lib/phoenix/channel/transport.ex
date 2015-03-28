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
    * Handle receiving outgoing `{:socket_push, %Phoenix.Socket.Message{}}` as
      Elixir process messages, then encoding and fowarding to remote client.
    * Trap exits and handle receiving `{:EXIT, socket_pid, reason}` messages
      and delete the entries from the kept HashDict of socket processes.

  See `Phoenix.Transports.WebSocket` for an example transport server implementation.


  ### Remote Client

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
    * `{:error, reason}` - Failed dispatch
    * `:ignore` - Unauthorized or unmatched dispatch

  """
  def dispatch(%Message{} = msg, sockets, transport_pid, router, endpoint, transport) do
    sockets
    |> HashDict.get(msg.topic)
    |> dispatch(msg, transport_pid, router, endpoint, transport)
  end

  @doc """
  Dispatches `%Phoenix.Socket.Message{}` in response to a heartbeat message sent from the client.

  The Message format sent to phoenix requires the following key / values:

    * topic - The String value "phoenix"
    * event - The String value "heartbeat"
    * payload - An empty JSON message payload, ie {}

  The server will respond to heartbeats with the same message
  """
  def dispatch(_, %{topic: "phoenix", event: "heartbeat"}, transport_pid, _router, _pubsub_server, _transport) do
    send transport_pid, {:socket_push, %Message{topic: "phoenix", event: "heartbeat", payload: %{}}}
  end
  def dispatch(nil, %{event: "join"} = msg, transport_pid, router, endpoint, transport) do
    case router.channel_for_topic(msg.topic, transport) do
      nil     -> log_ignore(msg.topic, router)
      channel ->
        socket = %Socket{transport_pid: transport_pid,
                  router: router,
                  endpoint: endpoint,
                  pubsub_server: endpoint.__pubsub_server__(),
                  topic: msg.topic,
                  ref: msg.ref,
                  channel: channel,
                  transport: transport}

        Phoenix.Channel.Server.start_link(socket, msg.payload)
    end
  end
  def dispatch(nil, msg, _transport_pid, router, _pubsub_server, _transport) do
    log_ignore(msg.topic, router)
    :ignore
  end
  def dispatch(socket_pid, msg, _transport_pid, _router, _pubsub_server, _transport) do
    GenServer.cast(socket_pid, {:handle_in, msg.event, msg.payload})
    :ok
  end
  defp log_ignore(topic, router) do
    Logger.debug fn -> "Ignoring unmatched topic \"#{topic}\" in #{inspect(router)}" end
    :ignore
  end

  @doc """
  Returns the `%Phoenix.Message{}` for a channel close event
  """
  def chan_close_message(topic) do
    %Message{topic: topic, event: "phx_chan_close", payload: %{}}
  end

  @doc """
  Returns the `%Phoenix.Message{}` for a channel error event
  """
  def chan_error_message(topic) do
    %Message{topic: topic, event: "phx_chan_error", payload: %{}}
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
