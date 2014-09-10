defmodule Phoenix.Router.Helpers do
  # Module that generates the routing helpers.
  @moduledoc false

  alias Phoenix.Config
  alias Phoenix.Router.Route

  @doc """
  Generates the router module for the given environment and routes.
  """
  def define(env, routes) do
    ast = for route <- routes, do: defhelper(route)
    url = url_from_config(env.module)

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
      Generates a URL for the given path.
      """
      def url(path), do: unquote(url) <> path

      @doc """
      Generates a URL for the given path considering the connection data.
      """
      # TODO: use host/port/schema from connection
      def url(%Plug.Conn{}, path), do: url(path)

      # Functions used by generated helpers

      defp to_path(segments, [], _reserved) do
        segments
      end

      defp to_path(segments, query, reserved) do
        dict = for {k, v} <- query,
               not (k = to_string(k)) in reserved,
               do: {k, v}

        case Plug.Conn.Query.encode dict do
          "" -> segments
          o  -> segments <> "?" <> o
        end
      end

      defp to_str(k), do: String.Chars.to_string(k)
    end

    Module.create(Module.concat(env.module, Helpers), code,
                  line: env.line, file: env.file)
  end

  @doc """
  Receives a router and generates a URL from its configuration.
  """
  def url_from_config(router) do
    sche = if Config.router(router, [:ssl]), do: "https", else: "http"
    # TODO: What happens if host and port are not available
    host = Config.router(router, [:host])
    port = Config.router(router, [:proxy_port]) ||
           Config.router(router, [:port])
    String.Chars.URI.to_string %URI{scheme: sche, host: host, port: port}
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
    segs = optimize_segments(route.segments)

    quote line: -1 do
      def unquote(:"#{helper}_path")(unquote(action), unquote_splicing(vars)) do
        unquote(:"#{helper}_path")(unquote(action), unquote_splicing(vars), [])
      end

      def unquote(:"#{helper}_path")(unquote(action), unquote_splicing(vars), params) do
        to_path(unquote(segs), params, unquote(bins))
      end
    end
  end

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
end
