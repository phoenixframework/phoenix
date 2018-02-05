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

  The transport requires one function:

    * `default_config/0` - returns the default transport configuration
      to be merged when the transport is declared in the socket module

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

  Most of those messages are user messages except:

    * "heartbeat" events in the "phoenix" topic - should just emit
      an OK reply
    * "phx_join" on any topic - should join the topic
    * "phx_leave" on any topic - should leave the topic

  The function `dispatch/3` can be used to handle these messages.

  ## Outgoing messages

  Channels can send two types of message back to a transport:
  `Phoenix.Socket.Message` and `Phoenix.Socket.Reply`. Those
  messages are encoded in the channel into a format defined by
  the transport. That's why transports are required to pass a
  serializer that abides to the behaviour described in
  `Phoenix.Transports.Serializer`.

  ## Managing channel exits

  Because channels are spawned from the transport process, transports
  must trap exits and correctly handle the `{:EXIT, _, _}` messages
  arriving from channels, relaying the proper response to the client.

  The `"phx_error"` event is sent by the transport when a channel exits,
  and represents the channel terminating against its will. The
  `on_exit_message/3` function aids in constructing the `"phx_error"` message.

  For graceful exits, the channel will notify the transort it is
  gracefully terminating via the following message:

      {:graceful_exit, channel_pid, %Phoenix.Socket.Message{}}

  The `%Phoenix.Socket.Message{}` is the leave message for the transport
  to relay to the client.

  ## Duplicate Join Subscriptions

  For a given topic, the client may only establish a single channel
  subscription. When attempting to create a duplicate subscription,
  `dispatch/3` will close the existing channel, log a warning, and
  spawn a new channel for the topic. When sending the `"phx_close"`
  event from the closed channel, the message will contain the `ref` the
  client sent when joining. This allows the client to uniquely identify
  `"phx_close"` and `"phx_error"` messages when force-closing a channel
  on duplicate joins.

  ## Security

  This module also provides functions to enable a secure environment
  on transports that, at some point, have access to a `Plug.Conn`.

  The functionality provided by this module helps in performing "origin"
  header checks and ensuring only SSL connections are allowed.

  ## Remote Client

  Channels can reply, synchronously, to any `handle_in/3` event. To match
  pushes with replies, clients must include a unique `ref` with every
  message and the channel server will reply with a matching ref where
  the client can pick up the callback for the matching reply.

  Phoenix includes a JavaScript client for WebSocket and Longpolling
  support using JSON encodings.

  Clients can be implemented for other protocols and encodings by
  abiding by the `Phoenix.Socket.Message` format.

  ## Protocol Versioning

  Clients are expected to send the Channel Transport protocol version that they
  expect to be talking to. The version can be retrieved on the server from
  `Phoenix.Channel.Transport.protocol_version/0`. If no version is provided, the
  Transport adapters should default to assume a `"1.0.0"` version number.
  See `web/static/js/phoenix.js` for an example transport client
  implementation.
  """

  require Logger
  alias Phoenix.Socket
  alias Phoenix.Socket.Message
  alias Phoenix.Socket.Reply

  @protocol_version "2.0.0"

  @doc """
  Provides a keyword list of default configuration for socket transports.
  """
  @callback default_config() :: Keyword.t

  @doc """
  Returns the Channel Transport protocol version.
  """
  def protocol_version, do: @protocol_version

  @doc """
  Handles the socket connection.

  It builds a new `Phoenix.Socket`, invokes the handler
  `connect/2` callback and returns the result.

  If the connection was successful, generates `Phoenix.PubSub`
  topic from the `id/1` callback.
  """
  def connect(endpoint, handler, transport_name, transport, serializer_config, params) do
    vsn = params["vsn"] || "1.0.0"

    case serializer_for_vsn(vsn, serializer_config) do
      {:ok, serializer} ->
        do_connect(vsn, endpoint, handler, transport_name, transport, serializer, params)
      {:error, reason} ->
        Logger.error(reason)
        :error
    end
  end
  defp serializer_for_vsn(vsn, serializer) when is_atom(serializer) do
    if Version.match?(vsn, "~> 1.0.0") do
      {:ok, serializer}
    else
      {:error, "The client's requested channel transport version \"#{vsn}\" " <>
               "does not match server's version requirements of \"~> 1.0.0\""}
    end
  rescue
    Version.InvalidVersionError ->
      {:error, "The client's requested channel transport version \"#{inspect vsn}\" " <>
               "is invalid"}
  end
  defp serializer_for_vsn(vsn, serializers) when is_list(serializers) do
    serializers
    |> Enum.find(fn {_serializer, vsn_req} -> Version.match?(vsn, vsn_req) end)
    |> case do
      {serializer, _vsn_req} -> {:ok, serializer}
      nil ->
        {:error, "The client's requested channel transport version \"#{vsn}\" " <>
                 "does not match server's version requirements of #{inspect serializers}"}
    end
  end

  defp do_connect(vsn, endpoint, handler, transport_name, transport, serializer, params) do
    socket = %Socket{endpoint: endpoint,
                     transport: transport,
                     transport_pid: self(),
                     transport_name: transport_name,
                     handler: handler,
                     vsn: vsn,
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
  Dispatches `Phoenix.Socket.Message` to a channel.

  All serialized, remote client messages should be deserialized and
  forwarded through this function by adapters.

  The following returns must be handled by transports:

    * `:noreply` - Nothing to be done by the transport
    * `{:reply, reply}` - The reply to be sent to the client
    * `{:joined, channel_pid, reply}` - The channel was joined
      and the reply must be sent as result
    * `{:error, reason, reply}` - An error occurred and the reply
      must be sent as result

  ## Parameter filtering on join

  When logging parameters, Phoenix can filter out sensitive parameters
  such as passwords and tokens. Parameters to be filtered can be added
  via the `:filter_parameters` option:

      config :phoenix, :filter_parameters, ["password", "secret"]

  With the configuration above, Phoenix will filter any parameter
  that contains the terms `password` or `secret`. The match is
  case sensitive.

  Phoenix's default is `["password"]`.

  """
  def dispatch(msg, channels, socket)

  def dispatch(%{ref: ref, topic: "phoenix", event: "heartbeat"}, _channels, socket) do
    {:reply, %Reply{join_ref: socket.join_ref, ref: ref, topic: "phoenix", status: :ok, payload: %{}}}
  end

  def dispatch(%Message{} = msg, channels, socket) do
    channels
    |> Map.get(msg.topic)
    |> do_dispatch(msg, socket)
  end

  @doc false
  def build_channel_socket(%Socket{} = socket, channel, topic, join_ref, opts) do
    %Socket{socket |
            topic: topic,
            channel: channel,
            join_ref: join_ref,
            assigns: Map.merge(socket.assigns, opts[:assigns] || %{}),
            private: channel.__socket__(:private)}
  end

  defp do_dispatch(nil, %{event: "phx_join", topic: topic} = msg, base_socket) do
    case base_socket.handler.__channel__(topic, base_socket.transport_name) do
      {channel, opts} ->
        socket = build_channel_socket(base_socket, channel, topic, msg.ref, opts)

        case Phoenix.Channel.Server.join(socket, msg.payload) do
          {:ok, response, pid} ->
            log socket, topic, fn -> "Replied #{topic} :ok" end
            {:joined, pid, %Reply{join_ref: socket.join_ref, ref: msg.ref, topic: topic, status: :ok, payload: response}}

          {:error, reason} ->
            log socket, topic, fn -> "Replied #{topic} :error" end
            {:error, reason, %Reply{join_ref: socket.join_ref, ref: msg.ref, topic: topic, status: :error, payload: reason}}
        end

      nil -> reply_ignore(msg, base_socket)
    end
  end

  defp do_dispatch(pid, %{event: "phx_join"} = msg, socket) when is_pid(pid) do
    Logger.debug "Duplicate channel join for topic \"#{msg.topic}\" in #{inspect(socket.handler)}. " <>
                 "Closing existing channel for new join."
    :ok = Phoenix.Channel.Server.close(pid)
    do_dispatch(nil, msg, socket)
  end

  defp do_dispatch(nil, msg, socket) do
    reply_ignore(msg, socket)
  end

  defp do_dispatch(channel_pid, msg, _socket) do
    send(channel_pid, msg)
    :noreply
  end

  defp log(_, "phoenix" <> _, _func), do: :noop
  defp log(%{ private: %{ log_join: false } }, _topic, _func), do: :noop
  defp log(%{ private: %{ log_join: level } }, _topic, func), do: Logger.log(level, func)

  defp reply_ignore(msg, socket) do
    Logger.warn fn -> "Ignoring unmatched topic \"#{msg.topic}\" in #{inspect(socket.handler)}" end
    {:error, :unmatched_topic, %Reply{join_ref: socket.join_ref, ref: msg.ref, topic: msg.topic, status: :error,
                                      payload: %{reason: "unmatched topic"}}}
  end

  @doc """
  Returns the message to be relayed when a channel exits.
  """
  def on_exit_message(topic, join_ref, _reason) do
    %Message{join_ref: join_ref, ref: join_ref, topic: topic, event: "phx_error", payload: %{}}
  end

  # TODO v2: Remove 2-arity
  @doc false
  def on_exit_message(topic, reason) do
    IO.warn "Phoenix.Transport.on_exit_message/2 is deprecated. Use on_exit_message/3 instead."
    on_exit_message(topic, nil, reason)
  end

  @doc false
  def notify_graceful_exit(%Socket{topic: topic, join_ref: ref} = socket) do
    close_msg = %Message{join_ref: ref, ref: ref, topic: topic, event: "phx_close", payload: %{}}
    send(socket.transport_pid, {:graceful_exit, self(), close_msg})
  end

  @doc """
  Forces SSL in the socket connection.

  Uses the endpoint configuration to decide so. It is a
  noop if the connection has been halted.
  """
  def force_ssl(%Plug.Conn{halted: true} = conn, _socket, _endpoint, _opts) do
    conn
  end

  def force_ssl(conn, socket, endpoint, opts) do
    if force_ssl = force_ssl_config(socket, endpoint, opts) do
      Plug.SSL.call(conn, force_ssl)
    else
      conn
    end
  end

  defp force_ssl_config(socket, endpoint, opts) do
    Phoenix.Config.cache(endpoint, {:force_ssl, socket}, fn _ ->
      opts =
        if force_ssl = Keyword.get(opts, :force_ssl, endpoint.config(:force_ssl)) do
          force_ssl
          |> Keyword.put_new(:host, {endpoint, :host, []})
          |> Plug.SSL.init()
        end
      {:cache, opts}
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

  Otherwise a 403 Forbidden response will be sent and the connection halted.
  It is a noop if the connection has been halted.
  """
  def check_origin(conn, handler, endpoint, opts, sender \\ &Plug.Conn.send_resp/1)

  def check_origin(%Plug.Conn{halted: true} = conn, _handler, _endpoint, _opts, _sender),
    do: conn

  def check_origin(conn, handler, endpoint, opts, sender) do
    import Plug.Conn
    origin       = get_req_header(conn, "origin") |> List.first
    check_origin = check_origin_config(handler, endpoint, opts)

    cond do
      is_nil(origin) or check_origin == false ->
        conn
      origin_allowed?(check_origin, URI.parse(origin), endpoint) ->
        conn
      true ->
        Logger.error """
        Could not check origin for Phoenix.Socket transport.

        This happens when you are attempting a socket connection to
        a different host than the one configured in your config/
        files. For example, in development the host is configured
        to "localhost" but you may be trying to access it from
        "127.0.0.1". To fix this issue, you may either:

          1. update [url: [host: ...]] to your actual host in the
             config file for your current environment (recommended)

          2. pass the :check_origin option when configuring your
             endpoint or when configuring the transport in your
             UserSocket module, explicitly outlining which origins
             are allowed:

                check_origin: ["https://example.com",
                               "//another.com:888", "//other.com"]
        """
        resp(conn, :forbidden, "")
        |> sender.()
        |> halt()
    end
  end

  defp check_origin_config(handler, endpoint, opts) do
    Phoenix.Config.cache(endpoint, {:check_origin, handler}, fn _ ->
      check_origin =
        case Keyword.get(opts, :check_origin, endpoint.config(:check_origin)) do
          origins when is_list(origins) ->
            Enum.map(origins, &parse_origin/1)
          boolean when is_boolean(boolean) ->
            boolean
        end
      {:cache, check_origin}
    end)
  end

  defp parse_origin(origin) do
    case URI.parse(origin) do
      %{host: nil} ->
        raise ArgumentError,
          "invalid check_origin: #{inspect origin}. " <>
          "Expected an origin with a host that is parsable by URI.parse/1. For example: " <>
          "[\"https://example.com\", \"//another.com:888\", \"//other.com\"]"
      %{scheme: scheme, port: port, host: host} ->
        {scheme, host, port}
    end
  end

  defp origin_allowed?(_check_origin, %URI{host: nil}, _endpoint),
    do: true
  defp origin_allowed?(true, uri, endpoint),
    do: compare?(uri.host, host_to_binary(endpoint.config(:url)[:host]))
  defp origin_allowed?(check_origin, uri, _endpoint) when is_list(check_origin),
    do: origin_allowed?(uri, check_origin)

  defp origin_allowed?(uri, allowed_origins) do
    %{scheme: origin_scheme, host: origin_host, port: origin_port} = uri

    Enum.any?(allowed_origins, fn {allowed_scheme, allowed_host, allowed_port} ->
      compare?(origin_scheme, allowed_scheme) and
      compare?(origin_port, allowed_port) and
      compare_host?(origin_host, allowed_host)
    end)
  end

  defp compare?(request_val, allowed_val) do
    is_nil(allowed_val) or request_val == allowed_val
  end

  defp compare_host?(_request_host, nil),
    do: true
  defp compare_host?(request_host, "*." <> allowed_host),
    do: String.ends_with?(request_host, allowed_host)
  defp compare_host?(request_host, allowed_host),
    do: request_host == allowed_host

  # TODO v1.4: Deprecate {:system, env_var}
  defp host_to_binary({:system, env_var}), do: host_to_binary(System.get_env(env_var))
  defp host_to_binary(host), do: host
end
