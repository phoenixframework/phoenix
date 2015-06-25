defmodule Phoenix.Router.Helpers do
  # Module that generates the routing helpers.
  @moduledoc false

  alias Phoenix.Router.Route
  alias Phoenix.Socket
  alias Plug.Conn

  @transports [Phoenix.Transports.WebSocket, Phoenix.Transports.LongPoller]

  @doc false
  def build_path(router, %Conn{} = conn, path) do
    conn
    |> build_own_forward_path(router, path)
    |> Kernel.||(build_conn_forward_path(conn, router, path))
    |> Kernel.||(path_with_script(path, conn.script_name))
  end

  defp build_own_forward_path(conn, router, path) do
    case Map.fetch(conn.private, router) do
      {:ok, {local_script, _}} ->
        path_with_script(path, local_script)
      :error -> nil
    end
  end

  defp build_conn_forward_path(conn, router, path) do
    case Map.fetch(conn.private, conn.private[:phoenix_router]) do
      {:ok, {_script_name, forwards}} ->
        case Map.fetch(forwards, router) do
          {:ok, local_script} ->
            path_with_script(path, conn.script_name ++ local_script)
          :error -> nil
        end
      :error -> nil
    end
  end

  defp path_with_script(path, []) do
    path
  end
  defp path_with_script(path, script) do
    "/" <> Enum.join(script, "/") <> path
  end

  @doc """
  Generates the helper module for the given environment and routes.
  """
  def define(env, routes) do
    ast = for {route, exprs} <- routes, do: defhelper(route, exprs)

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
      Generates the connection/endpoint base URL without any path information.
      """
      def url(%Conn{private: private}) do
        private.phoenix_endpoint.url
      end

      def url(%Socket{endpoint: endpoint}) do
        endpoint.url
      end

      def url(endpoint) when is_atom(endpoint) do
        endpoint.url
      end

      @doc """
      Generates the path information including any necessary prefix.
      """
      def path(%Conn{} = conn, path) do
        Phoenix.Router.Helpers.build_path(unquote(env.module), conn, path)
      end

      def path(%Socket{endpoint: endpoint}, path) do
        endpoint.path(path)
      end

      def path(endpoint, path) when is_atom(endpoint) do
        endpoint.path(path)
      end

      @doc """
      Generates path to a static asset given its file path.

      It expects either a conn or an endpoint.
      """
      def static_path(%Conn{private: private} = conn, path) do
        private.phoenix_endpoint.static_path(path)
      end

      def static_path(%Socket{endpoint: endpoint} = conn, path) do
        endpoint.static_path(path)
      end

      def static_path(endpoint, path) when is_atom(endpoint) do
        endpoint.static_path(path)
      end

      @doc """
      Generates url to a static asset given its file path.

      It expects either a conn or an endpoint.
      """
      def static_url(%Conn{private: private} = conn, path) do
        static_url(private.phoenix_endpoint, path)
      end

      def static_url(%Socket{endpoint: endpoint} = conn, path) do
        static_url(endpoint, path)
      end

      def static_url(endpoint, path) when is_atom(endpoint) do
        endpoint.static_url <> endpoint.static_path(path)
      end

      # Functions used by generated helpers

      defp to_param(int) when is_integer(int), do: Integer.to_string(int)
      defp to_param(bin) when is_binary(bin), do: bin
      defp to_param(false), do: "false"
      defp to_param(true), do: "true"
      defp to_param(data), do: Phoenix.Param.to_param(data)

      defp segments(segments, [], _reserved) do
        segments
      end

      defp segments(segments, query, reserved) do
        dict = for {k, v} <- query,
               not (k = to_string(k)) in reserved,
               do: {k, v}

        case Conn.Query.encode dict, &to_param/1 do
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

  In case a helper name was not given, or route is forwarded, returns nil.
  """
  def defhelper(%Route{helper: nil}, _exprs), do: nil
  def defhelper(%Route{kind: :forward}, _exprs), do: nil
  def defhelper(%Route{} = route, exprs) do
    helper = route.helper
    opts = route.opts

    {bins, vars} = :lists.unzip(exprs.binding)
    segs = expand_segments(exprs.path)

    # We are using -1 to avoid warnings in case a path has already been defined.
    quote line: -1 do
      def unquote(:"#{helper}_path")(conn_or_endpoint, unquote(opts), unquote_splicing(vars)) do
        unquote(:"#{helper}_path")(conn_or_endpoint, unquote(opts), unquote_splicing(vars), [])
      end

      def unquote(:"#{helper}_path")(conn_or_endpoint, unquote(opts), unquote_splicing(vars), params) do
        path(conn_or_endpoint, segments(unquote(segs), params, unquote(bins)))
      end

      def unquote(:"#{helper}_url")(conn_or_endpoint, unquote(opts), unquote_splicing(vars)) do
        unquote(:"#{helper}_url")(conn_or_endpoint, unquote(opts), unquote_splicing(vars), [])
      end

      def unquote(:"#{helper}_url")(conn_or_endpoint, unquote(opts), unquote_splicing(vars), params) do
        url(conn_or_endpoint) <> unquote(:"#{helper}_path")(conn_or_endpoint, unquote(opts), unquote_splicing(vars), params)
      end
    end
  end

  defp expand_segments([]), do: "/"
  defp expand_segments(segments) when is_list(segments),
    do: expand_segments(segments, "")
  defp expand_segments(segments),
    do: quote(do: "/" <> Enum.join(unquote(segments), "/"))

  defp expand_segments([{:|, _, [h, t]}], acc),
    do: quote(do: unquote(expand_segments([h], acc)) <> "/" <> Enum.join(unquote(t), "/"))
  defp expand_segments([h|t], acc) when is_binary(h),
    do: expand_segments(t, quote(do: unquote(acc) <> unquote("/" <> h)))
  defp expand_segments([h|t], acc),
    do: expand_segments(t, quote(do: unquote(acc) <> "/" <> to_param(unquote(h))))
  defp expand_segments([], acc),
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
      def channel_for_topic(_topic, _transport), do: nil
    end
  end

  defp to_topic_match(topic_pattern) do
    case String.split(topic_pattern, "*") do
      [prefix, ""] -> quote do: <<unquote(prefix) <> _rest>>
      [bare_topic] -> bare_topic
      _            -> raise ArgumentError, "channels using splat patterns must end with *"
    end
  end

  defp defchannel(topic_match, channel_module, transports) do
    quote do
      def channel_for_topic(unquote(topic_match), transport)
        when transport in unquote(transports) do

        unquote(channel_module)
      end
    end
  end
end
