defmodule Phoenix.VerifiedRoutes do
  @moduledoc """
  TODO

  use Phoenix.VerifiedRoutes, router: AppWeb.Router, endpoint: AppWeb.Endpoint
  """

  defmacro __using__(opts) do
    quote do
      opts = unquote(opts)
      # TODO quoted_literal?
      @router Keyword.fetch!(opts, :router)
      @endpoint Keyword.fetch!(opts, :endpoint)
      @statics Keyword.get(opts, :statics, [])
      import unquote(__MODULE__)
    end
  end

  defp raise_invalid_route(ast) do
    raise ArgumentError,
          "expected compile-time route path string, got: \n\n    #{Macro.to_string(ast)}\n"
  end

  defmacro path({:<<>>, _meta, _segments} = route) do
    {endpoint, router, statics} = attrs!(__CALLER__)
    {ast, _type} = verify_rewrite(endpoint, router, statics, route)

    ast
  end

  defmacro path(str) when is_binary(str) do
    {endpoint, router, statics} = attrs!(__CALLER__)
    {ast, _type} = verify_rewrite(endpoint, router, statics, str)

    ast
  end

  defmacro path(other), do: raise_invalid_route(other)

  defmacro path(endpoint, router, {:<<>>, _meta, _segments} = route) do
    endpoint = Macro.expand(endpoint, __CALLER__)
    router = Macro.expand(router, __CALLER__)
    {ast, _type} = verify_rewrite(endpoint, router, [], route)

    ast
  end

  defmacro path(endpoint, router, str) when is_binary(str) do
    endpoint = Macro.expand(endpoint, __CALLER__)
    router = Macro.expand(router, __CALLER__)
    {ast, _type} = verify_rewrite(endpoint, router, [], str)

    ast
  end

  defmacro path(_endpoint, _router, other), do: raise_invalid_route(other)

  defmacro path(conn_or_socket_or_endpoint_or_uri, {:<<>>, _meta, _segments} = route) do
    {_endpoint, router, statics} = attrs!(__CALLER__)
    {ast, _type} = verify_rewrite(conn_or_socket_or_endpoint_or_uri, router, statics, route)

    ast
  end

  defmacro path(conn_or_socket_or_endpoint_or_uri, route) when is_binary(route) do
    {_endpoint, router, statics} = attrs!(__CALLER__)
    {ast, _type} = verify_rewrite(conn_or_socket_or_endpoint_or_uri, router, statics, route)

    ast
  end

  defmacro path(_conn_or_socket_or_endpoint_or_uri, other), do: raise_invalid_route(other)

  defmacro sigil_p({:<<>>, _meta, _segments} = route, []) do
    {endpoint, router, statics} = attrs!(__CALLER__)
    {ast, _type} = verify_rewrite(endpoint, router, statics, route)

    ast
  end

  defmacro url(conn_or_socket_or_endpoint_or_uri, {:<<>>, _meta, _segments} = route) do
    verify_url(conn_or_socket_or_endpoint_or_uri, route, __CALLER__)
  end

  defmacro url(conn_or_socket_or_endpoint_or_uri, route) when is_binary(route) do
    verify_url(conn_or_socket_or_endpoint_or_uri, route, __CALLER__)
  end

  defmacro url(_conn_or_socket_or_endpoint_or_uri, other), do: raise_invalid_route(other)

  defp verify_url(endpoint_ctx, route, env) do
    {_endoint, router, statics} = attrs!(env)
    {rewrite, type} = verify_rewrite(endpoint_ctx, router, statics, route)

    quote do
      unquote(__MODULE__).__runtime_url__(unquote_splicing([type, endpoint_ctx, router, rewrite]))
    end
  end

  @doc false
  def __runtime_url__(:static, %Plug.Conn{} = conn, router, path) do
    __runtime_url__(:static, conn.private.phoenix_endpoint, router, path)
  end

  def __runtime_url__(_type, %Plug.Conn{private: private}, _router, path) do
    case private do
      %{phoenix_router_url: url} when is_binary(url) -> concat_url(url, path)
      %{phoenix_endpoint: endpoint} -> concat_url(endpoint.url(), path)
    end
  end

  def __runtime_url__(:static, %_{endpoint: endpoint}, router, path) do
    __runtime_url__(:static, endpoint, router, path)
  end
  def __runtime_url__(_type, %_{endpoint: endpoint}, _router, path) do
    concat_url(endpoint.url(), path)
  end

  def __runtime_url__(_type, %URI{} = uri, _router, path) do
    URI.to_string(%{uri | path: path})
  end

  def __runtime_url__(:static, endpoint, _router, path) when is_atom(endpoint) do
    endpoint.static_url() <> path
  end

  def __runtime_url__(_type, endpoint, _router, path) when is_atom(endpoint) do
    concat_url(endpoint.url(), path)
  end

  def __runtime_url__(_type, other, router, path) do
    raise ArgumentError,
          "expected a %Plug.Conn{}, a %Phoenix.Socket{}, a %URI{}, a struct with an :endpoint key, " <>
            "or a Phoenix.Endpoint when building url for #{inspect(router)} at #{path}, got: #{inspect(other)}"
  end

  defp concat_url(url, "/"), do: url
  defp concat_url(url, path) when is_binary(path), do: url <> path

  @doc false
  def __runtime_path__(type, %Plug.Conn{} = conn, router, path) do
    case type do
      :static -> conn.private.phoenix_endpoint.static_path(path)
      _other -> Phoenix.Router.Helpers.path(router, conn, path)
    end
  end

  def __runtime_path__(_type, %URI{} = uri, _router, path) do
    (uri.path || "") <> path
  end

  def __runtime_path__(type, %_{endpoint: endpoint}, router, path) do
    __runtime_path__(type, endpoint, router, path)
  end

  def __runtime_path__(type, endpoint, _router, path) when is_atom(endpoint) do
    case type do
      :static -> endpoint.static_path(path)
      _other -> endpoint.path(path)
    end
  end

  def __runtime_path__(_type, other, router, path) do
    raise ArgumentError,
          "expected a %Plug.Conn{}, a %Phoenix.Socket{}, a %URI{}, a struct with an :endpoint key, " <>
            "or a Phoenix.Endpoint when building path for #{inspect(router)} at #{path}, got: #{inspect(other)}"
  end

  defp verify_segment(["/" | rest], route, acc), do: verify_segment(rest, route, ["/" | acc])

  defp verify_segment(["/" <> _ = segment | rest], route, acc) do
    case {String.split(segment, "?"), rest} do
      {[segment], _} ->
        verify_segment(rest, route, [segment | acc])

      {[segment, ""],
       [{:"::", m1, [{{:., m2, [Kernel, :to_string]}, m2, [query_arg]}, {:binary, m4, nil}]}]} ->
        rewrite =
          {:"::", m1,
           [{{:., m2, [__MODULE__, :__encode_query__]}, m2, [query_arg]}, {:binary, m4, nil}]}

        {Enum.reverse([segment | acc]), [rewrite]}

      {[_segment, query], []} ->
        {Enum.reverse([segment | acc]), [query]}

      {[_segment, _], _} ->
        raise ArgumentError,
              "expected query string param to be compile-time map or keyword list, got: #{Macro.to_string(route)}"
    end
  end

  defp verify_segment([segment | _], route, _acc) when is_binary(segment) do
    raise ArgumentError, "path segments must begin with /, got: #{Macro.to_string(route)}"
  end

  defp verify_segment(
         [
           {:"::", m1, [{{:., m2, [Kernel, :to_string]}, m3, [dynamic]}, {:binary, m4, nil}]}
           | rest
         ],
         route,
         acc
       ) do
    rewrite =
      {:"::", m1, [{{:., m2, [Phoenix.Param, :to_param]}, m3, [dynamic]}, {:binary, m4, nil}]}

    verify_segment(rest, route, [rewrite | acc])
  end

  defp verify_segment([_other | _], route, _acc) do
    raise ArgumentError,
          "verified routes require a compile-time string, got: #{Macro.to_string(route)}"
  end

  defp verify_segment([], _route, acc), do: {Enum.reverse(acc), _query = []}

  @doc false
  def __encode_query__(dict) when is_list(dict) or is_map(dict) do
    case Plug.Conn.Query.encode(dict, &to_param/1) do
      "" -> ""
      query_str -> "?" <> query_str
    end
  end

  defp to_param(int) when is_integer(int), do: Integer.to_string(int)
  defp to_param(bin) when is_binary(bin), do: bin
  defp to_param(false), do: "false"
  defp to_param(true), do: "true"
  defp to_param(data), do: Phoenix.Param.to_param(data)

  defp verify_rewrite(endpoint, router, statics, route) when is_binary(route) do
    test_path =
      case String.split(route, "?") do
        [^route] -> route
        [path, _query] -> path
        _ -> raise ArgumentError, "invalid query string for path #{route}"
      end

    type = warn_on_umatched_route(router, statics, test_path, route)

    ast =
      quote do
        unquote(__MODULE__).__runtime_path__(unquote_splicing([type, endpoint, router, route]))
      end

    {ast, type}
  end

  defp verify_rewrite(endpoint, router, statics, {:<<>>, meta, segments} = route) do
    {path_rewrite, query_rewrite} = verify_segment(segments, route, [])

    test_path =
      Enum.map_join(path_rewrite, fn
        segment when is_binary(segment) -> segment
        _other -> "..."
      end)

    rewrite = {:<<>>, meta, path_rewrite ++ query_rewrite}
    type = warn_on_umatched_route(router, statics, test_path, route)

    ast =
      quote do
        unquote(__MODULE__).__runtime_path__(unquote_splicing([type, endpoint, router, rewrite]))
      end

    {ast, type}
  end

  defp warn_on_umatched_route(router, statics, test_path, route) do
    case Phoenix.Router.route_info(router, "GET", test_path, _host = nil) do
      %{} ->
        :match

      :error ->
        if static_path?(test_path, statics) do
          :static
        else
          IO.warn("no route path for #{inspect(router)} matches #{Macro.to_string(route)}")
          :error
        end
    end
  end

  defp attrs!(env) do
    endpoint = attr!(env.module, :endpoint)
    router = attr!(env.module, :router)
    statics = Module.get_attribute(env.module, :statics, [])
    Macro.expand({endpoint, router, statics}, env)
  end

  defp attr!(mod, name) do
    Module.get_attribute(mod, name) || raise "expected @#{name} module attribute to be set"
  end

  defp static_path?(path, statics) do
    Enum.find(statics, &String.starts_with?(path, "/" <> &1))
  end
end
