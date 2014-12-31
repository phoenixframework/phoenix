defmodule Phoenix.Router.Helpers do
  # Module that generates the routing helpers.
  @moduledoc false

  alias Phoenix.Router.Route
  alias Plug.Conn

  @transports [Phoenix.Transports.WebSocket, Phoenix.Transports.LongPoller]

  @doc """
  Generates the helper module for the given environment and routes.
  """
  def define(env, routes) do
    ast = for route <- routes, do: defhelper(route)

    # It is in general bad practice to generate large chunks of code
    # inside quoted expressions. However, we can get away with this
    # here for two reasons:
    #
    # * Helper modules are quite uncommon, typically one per project.
    #
    # * We inline most of the code for performance, so it is specific
    #   per helper module anyway.
    #
    code = quote do
      @moduledoc """
      Module with named helpers generated from #{inspect unquote(env.module)}.
      """
      unquote(ast)

      @doc """
      Generates a URL for the given path considering the connection data or
      Endpoint provided.
      """
      def url(%Conn{private: private}, path) do
        private.phoenix_endpoint.url(path)
      end
      def url(endpoint, path) when is_atom(endpoint) do
        endpoint.url(path)
      end

      @doc """
      Generates path to a static asset given its file path. It expects either a
      conn or an Endpoint.
      """
      def static_path(%Conn{private: private}, path) do
        static_path(private.phoenix_endpoint, path)
      end
      def static_path(endpoint, path) when is_atom(endpoint) do
        endpoint.static_path(path)
      end

      @doc """
      Generates url to a static asset given its file path. It expects either a
      conn or an Endpoint.
      """
      def static_url(%Conn{private: private}, path) do
        static_url(private.phoenix_endpoint, path)
      end
      def static_url(endpoint, path) do
        url(endpoint, static_path(endpoint, path))
      end

      # Functions used by generated helpers

      defp to_path(segments, [], _reserved) do
        segments
      end

      defp to_path(segments, query, reserved) do
        dict = for {k, v} <- query,
               not (k = to_string(k)) in reserved,
               do: {k, v}

        case Conn.Query.encode dict do
          "" -> segments
          o  -> segments <> "?" <> o
        end
      end
    end

    Module.create(Module.concat(env.module, Helpers), code,
                  line: env.line, file: env.file)
  end

  @doc """
  Receives a route and returns the quoted definition for its helper function.

  In case a helper name was not given, returns nil.
  """
  def defhelper(%Route{helper: nil}), do: nil

  def defhelper(%Route{} = route) do
    helper = route.helper
    action = route.action

    {bins, vars} = :lists.unzip(route.binding)
    segs = optimize_segments(route.path_segments)

    # We are using -1 to avoid warnings in case a path has already been defined.
    quote line: -1 do
      def unquote(:"#{helper}_path")(conn_or_endpoint, unquote(action), unquote_splicing(vars)) do
        unquote(:"#{helper}_path")(conn_or_endpoint, unquote(action), unquote_splicing(vars), [])
      end

      def unquote(:"#{helper}_path")(conn_or_endpoint, unquote(action), unquote_splicing(vars), params) do
        to_path(unquote(segs), params, unquote(bins))
      end

      def unquote(:"#{helper}_url")(conn_or_endpoint, unquote(action), unquote_splicing(vars)) do
        unquote(:"#{helper}_url")(conn_or_endpoint, unquote(action), unquote_splicing(vars), [])
      end

      def unquote(:"#{helper}_url")(conn_or_endpoint, unquote(action), unquote_splicing(vars), params) do
        url(conn_or_endpoint, unquote(:"#{helper}_path")(conn_or_endpoint, unquote(action), unquote_splicing(vars), params))
      end
    end
  end

  defp optimize_segments([]), do: "/"
  defp optimize_segments(segments) when is_list(segments),
    do: optimize_segments(segments, "")
  defp optimize_segments(segments),
    do: quote(do: "/" <> Enum.join(unquote(segments), "/"))

  defp optimize_segments([{:|, _, [h, t]}], acc),
    do: quote(do: unquote(optimize_segments([h], acc)) <> "/" <> Enum.join(unquote(t), "/"))
  defp optimize_segments([h|t], acc) when is_binary(h),
    do: optimize_segments(t, quote(do: unquote(acc) <> unquote("/" <> h)))
  defp optimize_segments([h|t], acc),
    do: optimize_segments(t, quote(do: unquote(acc) <> "/" <> to_string(unquote(h))))
  defp optimize_segments([], acc),
    do: acc


  @doc """
  Receives the `@channels` accumulated module attribute and returns an AST of
  `match_channel` definitions
  """
  def defchannels(channels) do
    channels_ast = for {topic_pattern, module, opts} <- channels do
      topic_pattern
      |> to_topic_match
      |> defchannel(module, opts[:via] || @transports)
    end

    quote do
      unquote(channels_ast)
      def match_channel(socket, _direction, _channel, _event, _msg_payload, _transport) do
        {:error, socket, :bad_transport_match}
      end
    end
  end

  defp to_topic_match(topic_pattern) do
    case String.split(topic_pattern, "*") do
      [prefix, ""] -> quote do: <<unquote(prefix) <> _rest>>
      [bare_topic] -> bare_topic
      _            -> raise "channels using splat patterns must end with *"
    end
  end

  defp defchannel(topic_match, module, transports) do
    quote do
      def match_channel(socket, :incoming, unquote(topic_match), "join", msg_payload, transport)
        when transport in unquote(transports) do
        apply(unquote(module), :join, [socket.topic, msg_payload, socket])
      end
      def match_channel(socket, :incoming, unquote(topic_match), "leave", msg_payload, transport)
        when transport in unquote(transports) do
        apply(unquote(module), :leave, [msg_payload, socket])
      end
      def match_channel(socket, :incoming, unquote(topic_match), event, msg_payload, transport)
        when transport in unquote(transports) do
        apply(unquote(module), :incoming, [event, msg_payload, socket])
      end
      def match_channel(socket, :outgoing, unquote(topic_match), event, msg_payload, _transport) do
        apply(unquote(module), :outgoing, [event, msg_payload, socket])
      end
    end
  end
end
