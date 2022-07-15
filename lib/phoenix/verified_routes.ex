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
          "expected compile-time ~p path string, got: #{Macro.to_string(ast)}"
  end

  defp verify_path(env, {endpoint, router, statics}, route) do
    {rewrite_ast, _type} = verify_rewrite(env, endpoint, router, statics, route)

    rewrite_ast
  end

  @doc """
  TODO
  """
  defmacro path({:sigil_p, _, [{:<<>>, _meta, _segments} = route, _]}) do
    verify_path(__CALLER__, attrs!(__CALLER__), route)
  end

  defmacro path({:sigil_p, _, [str, _]}) when is_binary(str) do
    verify_path(__CALLER__, attrs!(__CALLER__), str)
  end

  defmacro path(other), do: raise_invalid_route(other)

  defmacro path(endpoint, router, {:sigil_p, _, [{:<<>>, _meta, _segments} = route, _]}) do
    endpoint = Macro.expand(endpoint, __CALLER__)
    router = Macro.expand(router, __CALLER__)
    verify_path(__CALLER__, {endpoint, router, []}, route)
  end

  defmacro path(endpoint, router, {:sigil_p, _, [str, _]}) when is_binary(str) do
    verify_path(__CALLER__, {endpoint, router, []}, str)
  end

  defmacro path(_endpoint, _router, other), do: raise_invalid_route(other)

  defmacro path(
             conn_or_socket_or_endpoint_or_uri,
             {:sigil_p, _, [{:<<>>, _meta, _segments} = route, _]}
           ) do
    {_endpoint, router, statics} = attrs!(__CALLER__)
    verify_path(__CALLER__, {conn_or_socket_or_endpoint_or_uri, router, statics}, route)
  end

  defmacro path(conn_or_socket_or_endpoint_or_uri, {:sigil_p, _, [route, _]})
           when is_binary(route) do
    {_endpoint, router, statics} = attrs!(__CALLER__)
    verify_path(__CALLER__, {conn_or_socket_or_endpoint_or_uri, router, statics}, route)
  end

  defmacro path(_conn_or_socket_or_endpoint_or_uri, other), do: raise_invalid_route(other)

  @doc """
  TODO
  """
  defmacro sigil_p({:<<>>, _meta, _segments} = route, []) do
    verify_path(__CALLER__, attrs!(__CALLER__), route)
  end

  @doc """
  TODO
  """
  defmacro url(
             conn_or_socket_or_endpoint_or_uri,
             {:sigil_p, _, [{:<<>>, _meta, _segments} = route, _]}
           ) do
    verify_url(conn_or_socket_or_endpoint_or_uri, route, __CALLER__)
  end

  defmacro url(conn_or_socket_or_endpoint_or_uri, {:sigil_p, _, [route, _]})
           when is_binary(route) do
    verify_url(conn_or_socket_or_endpoint_or_uri, route, __CALLER__)
  end

  defmacro url(_conn_or_socket_or_endpoint_or_uri, other),
    do: raise_invalid_route(IO.inspect(other))

  defp verify_url(endpoint_ctx, route, env) do
    {_endoint, router, statics} = attrs!(env)

    case verify_rewrite(env, endpoint_ctx, router, statics, route) do
      {rewrite, :static} ->
        quote do
          unquote(__MODULE__).static_url(unquote_splicing([endpoint_ctx, router, rewrite]))
        end

      {rewrite, _match_or_error} ->
        quote do
          unquote(__MODULE__).unverified_url(unquote_splicing([endpoint_ctx, router, rewrite]))
        end
    end
  end

  @doc """
  TODO
  """
  def static_url(%Plug.Conn{private: private}, router, path) do
    case private do
      %{phoenix_static_url: static_url} -> concat_url(static_url, path)
      %{phoenix_endpoint: endpoint} -> static_url(endpoint, router, path)
    end
  end

  def static_url(%_{endpoint: endpoint}, router, path) do
    static_url(endpoint, router, path)
  end

  def static_url(endpoint, _router, path) when is_atom(endpoint) do
    endpoint.static_url() <> path
  end

  def static_url(other, router, path) do
    raise ArgumentError,
          "expected a %Plug.Conn{}, a %Phoenix.Socket{}, a %URI{}, a struct with an :endpoint key, " <>
            "or a Phoenix.Endpoint when building static url for #{inspect(router)} at #{path}, got: #{inspect(other)}"
  end

  @doc """
  TODO
  """
  def unverified_url(%Plug.Conn{private: private}, _router, path) do
    case private do
      %{phoenix_router_url: url} when is_binary(url) -> concat_url(url, path)
      %{phoenix_endpoint: endpoint} -> concat_url(endpoint.url(), path)
    end
  end

  def unverified_url(%_{endpoint: endpoint}, _router, path) do
    concat_url(endpoint.url(), path)
  end

  def unverified_url(%URI{} = uri, _router, path) do
    URI.to_string(%{uri | path: path})
  end

  def unverified_url(endpoint, _router, path) when is_atom(endpoint) do
    concat_url(endpoint.url(), path)
  end

  def unverified_url(other, router, path) do
    raise ArgumentError,
          "expected a %Plug.Conn{}, a %Phoenix.Socket{}, a %URI{}, a struct with an :endpoint key, " <>
            "or a Phoenix.Endpoint when building url for #{inspect(router)} at #{path}, got: #{inspect(other)}"
  end

  defp concat_url(url, "/"), do: url
  defp concat_url(url, path) when is_binary(path), do: url <> path

  @doc """
  TODO
  """
  def static_path(%Plug.Conn{private: private}, _router, path) do
    case private do
      %{phoenix_static_url: _} -> path
      %{phoenix_endpoint: endpoint} -> endpoint.static_path(path)
    end
  end

  def static_path(%URI{} = uri, _router, path) do
    (uri.path || "") <> path
  end

  def static_path(%_{endpoint: endpoint}, router, path) do
    static_path(endpoint, router, path)
  end

  def static_path(endpoint, _router, path) when is_atom(endpoint) do
    endpoint.static_path(path)
  end

  @doc """
  TODO
  """
  def unverified_path(%Plug.Conn{} = conn, router, path) do
    # TODO move primary code for path here
    Phoenix.Router.Helpers.path(router, conn, path)
  end

  def unverified_path(%URI{} = uri, _router, path) do
    (uri.path || "") <> path
  end

  def unverified_path(%_{endpoint: endpoint}, router, path) do
    unverified_path(endpoint, router, path)
  end

  def unverified_path(endpoint, _router, path) when is_atom(endpoint) do
    endpoint.path(path)
  end

  def unverified_path(other, router, path) do
    raise ArgumentError,
          "expected a %Plug.Conn{}, a %Phoenix.Socket{}, a %URI{}, a struct with an :endpoint key, " <>
            "or a Phoenix.Endpoint when building path for #{inspect(router)} at #{path}, got: #{inspect(other)}"
  end

  defp verify_segment(["/" | rest], route, acc), do: verify_segment(rest, route, ["/" | acc])

  # we've found a static segment, return to caller with rewritten query if found
  defp verify_segment(["/" <> _ = segment | rest], route, acc) do
    case {String.split(segment, "?"), rest} do
      {[segment], _} ->
        verify_segment(rest, route, [URI.encode(segment) | acc])

      {[segment, ""], [{:"::", _, _}] = query} ->
        {Enum.reverse([URI.encode(segment) | acc]), [verify_query(query, route)]}

      {[segment, query], []} ->
        {Enum.reverse([URI.encode(segment) <> "?" | acc]), [query]}

      {[_segment, _], _} ->
        raise_invalid_query(route)
    end
  end

  # we reached the static query string, return to caller
  defp verify_segment(["?" <> _ = query], _route, acc) do
    {Enum.reverse(acc), [query]}
  end

  # we reached the dynamic query string, return to call with rewritten query
  defp verify_segment(["?" | rest], route, acc) do
    {Enum.reverse(acc), [verify_query(rest, route)]}
  end

  defp verify_segment([segment | _], route, _acc) when is_binary(segment) do
    raise ArgumentError,
          "path segments must begin with /, got: #{inspect(segment)} in #{Macro.to_string(route)}"
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

  # we've reached the end of the path without finding query, return to caller
  defp verify_segment([], _route, acc), do: {Enum.reverse(acc), _query = []}

  defp verify_query(
         [{:"::", m1, [{{:., m2, [Kernel, :to_string]}, m2, [arg]}, {:binary, m4, nil}]}],
         _route
       ) do
    {:"::", m1, [{{:., m2, [__MODULE__, :__encode_query__]}, m2, [arg]}, {:binary, m4, nil}]}
  end

  defp verify_query(_other, route) do
    raise_invalid_query(route)
  end

  defp raise_invalid_query(route) do
    raise ArgumentError,
          "expected query string param to be compile-time map or keyword list, got: #{Macro.to_string(route)}"
  end

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

  defp verify_rewrite(env, endpoint, router, statics, route) when is_binary(route) do
    test_path =
      case String.split(route, "?") do
        [^route] -> route
        [path, _query] -> path
        _ -> raise ArgumentError, "invalid query string for path #{route}"
      end

    rewrite_path(env, endpoint, router, route, statics, test_path)
  end

  defp verify_rewrite(env, endpoint, router, statics, {:<<>>, meta, segments} = route) do
    {path_rewrite, query_rewrite} = verify_segment(segments, route, [])

    test_path =
      Enum.map_join(path_rewrite, fn
        segment when is_binary(segment) -> segment
        _other -> "..."
      end)

    rewrite_route = {:<<>>, meta, path_rewrite ++ query_rewrite}
    rewrite_path(env, endpoint, router, rewrite_route, statics, test_path)
  end

  defp rewrite_path(env, endpoint, router, route, statics, test_path) do
    type = warn_on_umatched_route(env, router, statics, test_path, route)

    ast =
      case type do
        match when match in [:match, :error] ->
          quote do
            unquote(__MODULE__).unverified_path(unquote_splicing([endpoint, router, route]))
          end

        :static ->
          quote do
            unquote(__MODULE__).static_path(unquote_splicing([endpoint, router, route]))
          end
      end

    {ast, type}
  end

  defp warn_on_umatched_route(env, router, statics, test_path, route) do
    if static_path?(test_path, statics) do
      :static
    else
      case Phoenix.Router.route_info(router, "GET", test_path, _host = nil) do
        %{} ->
          :match

        :error ->
          IO.warn(
            "no route path for #{inspect(router)} matches #{Macro.to_string(route)}",
            Macro.Env.stacktrace(env)
          )

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
