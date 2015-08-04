defmodule Phoenix.Socket.Transport do
  @moduledoc """
  API for building transports.

  This module describes what is required to build a Phoenix transport.
  The transport sits between the socket and channels, forwarding client
  messages to channels and vice-versa.

  A transport is responsible for:

    * Implementing the transport behaviour
    * Establishing the socket connection
    * Handling of incoming messages
    * Handling of outgoing messages
    * Managing channels
    * Providing secure defaults

  ## The transport behaviour
  
  The transport requires two functions:

    * `default_config/0` - returns the default transport configuration
      to be merged whent the transport is declare in the socket module

    * `handlers/0` - returns a map of handlers. For example, if the
      transport can be run cowboy, it just need to specify the
      appropriate cowboy handler

  ## Socket connections

  Once a connection is established, the transport is responsible
  for invoking the `Phoenix.Socket.connect/2` callback and acting
  accordingly. Once connected, the transport should request the
  `Phoenix.Socket.id/1` and subscribe to the topic if one exists.
  On subscribed, the transport must be able to handle "disconnect"
  broadcasts on the given id topic.

  The `connect/6` function in this module can be used as a
  convenience or a documentation on such steps.

  ## Incoming messages

  Incoming messages are encoded in whatever way the transport
  chooses. Those messages must be decoded in the transport into a
  `Phoenix.Socket.Message` before being forwarded to a channel.

  Most of those messages are user messages except by:

    * "heartbeat" events in the "phoenix" topic - should just emit
      an OK reply
    * "phx_join" on any topic - should join the topic
    * "phx_leave" on any topic - should leave the topic

  The function `dispatch/3` can help with handling of such messages.

  ## Outgoing messages

  Channels can send two types of messages back to a transport:
  `Phoenix.Socket.Message` and `Phoenix.Socket.Reply`. Those
  messages are encoded in the channel into a format defined by
  the transport. That's why transports are required to pass a
  serializer that abides to the behaviour described in
  `Phoenix.Transports.Serializer`.

  ## Managing channels

  Because channels are spawned from the transport process, transports
  must trap exists and correctly handle the `{:EXIT, _, _}` messages
  arriving from channels, relaying the proper response to the client.

  The function `on_exit/3` should aid with that.

  ## Security

  This module also provides functions to enable a secure environment
  on transports that, at some point, have access to a `Plug.Conn`.

  The functionality provided by this module help with doing "origin"
  header checks and ensuring only SSL connections are allowed.

  ## Remote Client

  Channels can reply, synchronously, to any `handle_in/3` event. To match
  pushes with replies, clients must include a unique `ref` with every
  message and the channel server will reply with a matching ref where
  the client and pick up the callback for the matching reply.

  Phoenix includes a JavaScript client for WebSocket and Longpolling
  support using JSON encodings.

  However, a client can be implemented for other protocols and encodings by
  abiding by the `Phoenix.Socket.Message` format.

  See `web/static/js/phoenix.js` for an example transport client
  implementation.
  """

  use Behaviour
  require Logger
  alias Phoenix.Socket
  alias Phoenix.Socket.Message
  alias Phoenix.Socket.Reply

  @doc """
  Provides a keyword list of default configuration for socket transports.
  """
  defcallback default_config() :: Keyword.t

  @doc """
  Provides handlers for different applications.
  """
  defcallback handlers() :: map

  @doc """
  Handles the socket connection.

  It builds a new `Phoenix.Socket` and invokes the handler
  `connect/2` callback and returns the result.

  If the connection was successful, generates `Phoenix.PubSub`
  topic from the `id/1` callback.
  """
  def connect(endpoint, handler, transport_name, transport, serializer, params) do
    socket = %Socket{endpoint: endpoint,
                     transport: transport,
                     transport_name: transport_name,
                     handler: handler,
                     pubsub_server: endpoint.__pubsub_server__,
                     serializer: serializer}

    case handler.connect(params, socket) do
      {:ok, socket} ->
        case handler.id(socket) do
          nil                   -> {:ok, socket}
          id when is_binary(id) -> {:ok, %Socket{socket | id: id}}
          invalid               ->
            Logger.error "#{inspect handler}.id/1 returned invalid identifier #{inspect invalid}. " <>
                         "Expected nil or a string."
            :error
        end

      :error ->
        :error

      invalid ->
        Logger.error "#{inspect handler}.connect/2 returned invalid value #{inspect invalid}. " <>
                     "Expected {:ok, socket} or :error"
        :error
    end
  end

  @doc """
  Dispatches `%Phoenix.Socket.Message{}` to Channel. All serialized, remote client messages
  should be deserialized and forwarded through this function by adapters.

  The following return signatures must be handled by transport adapters:
    * `{:ok, socket_pid}` - Successful dispatch, with pid of new socket
    * `{:error, reason}` - Unauthorized or unmatched dispatch

  """
  def dispatch(msg, sockets, socket)

  def dispatch(%{ref: ref, topic: "phoenix", event: "heartbeat"}, _sockets, _socket) do
    {:reply, %Reply{ref: ref, topic: "phoenix", status: :ok, payload: %{}}}
  end

  def dispatch(%Message{} = msg, sockets, socket) do
    sockets
    |> HashDict.get(msg.topic)
    |> do_dispatch(msg, socket)
  end

  defp do_dispatch(nil, %{event: "phx_join", topic: topic} = msg, socket) do
    if channel = socket.handler.__channel__(topic, socket.transport_name) do
      socket = %Socket{socket | topic: topic, channel: channel}

      log_info topic, fn ->
        "JOIN #{topic} to #{inspect(channel)}\n" <>
        "  Transport:  #{inspect socket.transport}\n" <>
        "  Parameters: #{inspect msg.payload}"
      end

      case Phoenix.Channel.Server.join(socket, msg.payload) do
        {:ok, response, pid} ->
          log_info topic, fn -> "Replied #{topic} :ok" end
          {:joined, pid, %Reply{ref: msg.ref, topic: topic, status: :ok, payload: response}}

        {:error, reason} ->
          log_info topic, fn -> "Replied #{topic} :error" end
          {:error, reason, %Reply{ref: msg.ref, topic: topic, status: :error, payload: reason}}
      end
    else
      reply_ignore(msg, socket)
    end
  end

  defp do_dispatch(nil, msg, socket) do
    reply_ignore(msg, socket)
  end

  defp do_dispatch(socket_pid, msg, _socket) do
    send(socket_pid, msg)
    :noreply
  end

  defp log_info("phoenix" <> _, _func), do: :noop
  defp log_info(_topic, func), do: Logger.info(func)

  defp reply_ignore(msg, socket) do
    Logger.debug fn -> "Ignoring unmatched topic \"#{msg.topic}\" in #{inspect(socket.handler)}" end
    {:error, :unmatched_topic, %Reply{ref: msg.ref, topic: msg.topic, status: :error,
                                      payload: %{reason: "unmatched topic"}}}
  end

  @doc """
  Returns the `%Phoenix.Message{}` for a channel close event
  """
  def channel_close_message(topic) do
    %Message{topic: topic, event: "phx_close", payload: %{}}
  end

  @doc """
  Returns the `%Phoenix.Message{}` for a channel error event
  """
  def channel_error_message(topic) do
    %Message{topic: topic, event: "phx_error", payload: %{}}
  end

  @doc """
  Forces SSL in the socket connection.

  Uses the endpoint configuration to decide so. It is a
  noop if the connection has been halted.
  """
  def force_ssl(%Plug.Conn{halted: true} = conn, _socket, _endpoint) do
    conn
  end

  def force_ssl(conn, socket, endpoint) do
    if force_ssl = force_ssl_config(socket, endpoint) do
      Plug.SSL.call(conn, Plug.SSL.init(force_ssl))
    else
      conn
    end
  end

  defp force_ssl_config(socket, endpoint) do
    Phoenix.Config.cache(endpoint, {:force_ssl, socket}, fn _ ->
      {:cache,
        if force_ssl = endpoint.config(:force_ssl) do
          Keyword.put_new(force_ssl, :host, endpoint.config(:url)[:host] || "localhost")
        end}
    end)
  end

  @doc """
  Logs the transport request.

  Available for transports that generate a connection.
  """
  def transport_log(conn, level) do
    if level do
      Plug.Logger.call(conn, Plug.Logger.init(log: level))
    else
      conn
    end
  end

  @doc """
  Checks the origin request header against the list of allowed origins.

  Should be called by transports before connecting when appropriate.
  If the origin header matches the allowed origins, no origin header was
  sent or no origin was configured, it will return the given connection.

  Otherwise a otherwise a 403 Forbidden response will be sent and
  the connection halted.  It is a noop if the connection has been halted.
  """
  def check_origin(conn, endpoint, check_origin, sender \\ &Plug.Conn.send_resp/1)

  def check_origin(%Plug.Conn{halted: true} = conn, _endpoint, _check_origin, _sender),
    do: conn

  def check_origin(conn, endpoint, check_origin, sender) do
    import Plug.Conn
    origin = get_req_header(conn, "origin") |> List.first

    cond do
      is_nil(origin) ->
        conn
      origin_allowed?(check_origin, origin, endpoint) ->
        conn
      true ->
        resp(conn, :forbidden, "")
        |> sender.()
        |> halt()
    end
  end

  defp origin_allowed?(false, _, _),
    do: true
  defp origin_allowed?(true, origin, endpoint),
    do: compare?(URI.parse(origin).host, endpoint.config(:url)[:host])
  defp origin_allowed?(check_origin, origin, _endpoint) when is_list(check_origin),
    do: origin_allowed?(origin, check_origin)

  defp origin_allowed?(origin, allowed_origins) do
    origin = URI.parse(origin)

    Enum.any?(allowed_origins, fn allowed ->
      allowed = URI.parse(allowed)

      compare?(origin.scheme, allowed.scheme) and
      compare?(origin.port, allowed.port) and
      compare?(origin.host, allowed.host)
    end)
  end

  defp compare?(_, nil), do: true
  defp compare?(x, y),   do: x == y
end
