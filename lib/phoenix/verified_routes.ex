defmodule Phoenix.VerifiedRoutes do
  @moduledoc """
  TODO

  use Phoenix.VerifiedRoutes, router: AppWeb.Router, endpoint: AppWeb.Endpoint
  """

  defmacro __using__(opts) do
    quote do
      opts = unquote(opts)
      router = Keyword.fetch!(opts, :router)
      endpoint = Keyword.fetch!(opts, :endpoint)
      import unquote(__MODULE__)
      # TODO quoted_literal?
      @phoenix_verified %{router: router, endpoint: endpoint}
    end
  end

  defp raise_invalid_route(ast) do
    raise ArgumentError,
          "expected compile-time route path string, got: \n\n    #{Macro.to_string(ast)}\n"
  end

  defmacro path({:<<>>, _meta, _segments} = route) do
    %{router: router, endpoint: endpoint} =
      Module.get_attribute(__CALLER__.module, :phoenix_verified)

    verify_rewrite(endpoint, router, route)
  end

  defmacro path(other), do: raise_invalid_route(other)

  defmacro path(endpoint, router, {:<<>>, _meta, _segments} = route) do
    verify_rewrite(endpoint, router, route)
  end

  defmacro path(_endpoint, _router, other), do: raise_invalid_route(other)

  defmacro path(conn_or_socket_or_endpoint_or_uri, {:<<>>, _meta, _segments} = route) do
    %{router: router} = Module.get_attribute(__CALLER__.module, :phoenix_verified)
    verify_rewrite(conn_or_socket_or_endpoint_or_uri, router, route)
  end

  defmacro path(_conn_or_socket_or_endpoint_or_uri, other), do: raise_invalid_route(other)

  defmacro sigil_p({:<<>>, _meta, _segments} = route, []) do
    %{router: router, endpoint: endpoint} =
      Module.get_attribute(__CALLER__.module, :phoenix_verified)

    verify_rewrite(endpoint, router, route)
  end

  defmacro url(conn_or_socket_or_endpoint_or_uri, {:<<>>, _meta, _segments} = route) do
    %{router: router} = Module.get_attribute(__CALLER__.module, :phoenix_verified)
    rewrite_route = verify_rewrite(conn_or_socket_or_endpoint_or_uri, router, route)

    quote do
      unuqote(__MODULE__).__runtime_url__(
        unquote(conn_or_socket_or_endpoint_or_uri),
        unquote(router),
        unquote(rewrite_route)
      )
    end
  end

  defmacro url(_conn_or_socket_or_endpoint_or_uri, other), do: raise_invalid_route(other)

  @doc false
  def __runtime_url__(%Plug.Conn{private: private}, _router, path) do
    case private do
      %{phoenix_router_url: url} when is_binary(url) -> url <> path
      %{phoenix_endpoint: endpoint} -> endpoint.url() <> path
    end
  end

  def __runtime_url__(%_{endpoint: endpoint}, _router, path) do
    endpoint.url() <> path
  end

  def __runtime_url__(%URI{} = uri, _router, path) do
    URI.to_string(%{uri | path: path})
  end

  def __runtime_url__(endpoint, _router, path) when is_atom(endpoint) do
    endpoint.url() <> path
  end

  def __runtime_url__(other, router, path) do
    raise ArgumentError,
          "expected a %Plug.Conn{}, a %Phoenix.Socket{}, a %URI{}, a struct with an :endpoint key, " <>
            "or a Phoenix.Endpoint when building url for #{inspect(router)} at #{path}, got: #{inspect(other)}"
  end

  @doc false
  def __runtime_path__(%Plug.Conn{} = conn, router, path) do
    Phoenix.Router.Helpers.path(router, conn, path)
  end

  def __runtime_path__(%URI{} = uri, _router, path) do
    (uri.path || "") <> path
  end

  def __runtime_path__(%_{endpoint: endpoint}, _router, path) do
    endpoint.path(path)
  end

  def __runtime_path__(endpoint, _router, path) when is_atom(endpoint) do
    endpoint.path(path)
  end

  def __runtime_path__(other, router, path) do
    raise ArgumentError,
          "expected a %Plug.Conn{}, a %Phoenix.Socket{}, a %URI{}, a struct with an :endpoint key, " <>
            "or a Phoenix.Endpoint when building path for #{inspect(router)} at #{path}, got: #{inspect(other)}"
  end

  defp verify_segment(["/" | rest], route, acc), do: verify_segment(rest, route, ["/" | acc])

  defp verify_segment(["/" <> _ = segment | rest], route, acc) do
    case {String.split(segment, "?"), rest} do
      {[segment], _} ->
        verify_segment(rest, route, [segment | acc])

      {[segment, ""], [{:"::", m1, [{{:., m2, [Kernel, :to_string]}, m2, [query_arg]}, {:binary, m4, nil}]}]} ->
        rewrite = {:"::", m1, [{{:., m2, [__MODULE__, :__encode_query__]}, m2, [query_arg]}, {:binary, m4, nil}]}
        {Enum.reverse([segment | acc]), [rewrite]}

      {[_segment, query], []} ->
        {Enum.reverse([segment | acc]), [query]}

      {[_segment, _], _} ->
        raise ArgumentError, "expected query string param to be compile-time map or keyword list, got: #{Macro.to_string(route)}"
    end
  end

  defp verify_segment([segment | _], route, _acc) when is_binary(segment) do
    raise ArgumentError, "path segments must begin with /, got: #{Macro.to_string(route)}"
  end

  defp verify_segment(
         [{:"::", m1, [{{:., m2, [Kernel, :to_string]}, m3, [dynamic]}, {:binary, m4, nil}]} | rest],
         route,
         acc
       ) do
    rewrite = {:"::", m1, [{{:., m2, [Phoenix.Param, :to_param]}, m3, [dynamic]}, {:binary, m4, nil}]}
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

  defp verify_rewrite(endpoint_ctx, router, {:<<>>, meta, segments} = route) do
    {path_rewrite, query_rewrite} = verify_segment(segments, route, [])
      # Enum.map_reduce(segments, @segments, fn
      #   "/", @segments ->
      #     {"/", @segments}

      #   "/" <> _ = segment, @segments ->
      #     if String.ends_with?(segment, "?") do
      #       {"todo", :query}
      #     else
      #       {segment, @segments}
      #     end

      #   segment when is_binary(segment), @segments ->
      #     raise ArgumentError, "path segments must begin with /"

      #   {:"::", m1, [{{:., m2, [Kernel, :to_string]}, m3, [dynamic]}, {:binary, m4, nil}]},
      #   @segments ->
      #     ast =
      #       {:"::", m1, [{{:., m2, [Phoenix.Param, :to_param]}, m3, [dynamic]}, {:binary, m4, nil}]}

      #     {ast, @segments}

      #   other, @segments ->
      #     raise ArgumentError,
      #           "verified routes require a compile-time string, got: #{inspect(other)}"
      # end)

    test_path =
      Enum.map_join(path_rewrite, fn
        segment when is_binary(segment) -> segment
        _other -> "..."
      end)

    case Phoenix.Router.route_info(router, "GET", test_path, _host = nil) do
      %{} -> :ok
      :error -> IO.warn("no route path for #{inspect(router)} matches #{Macro.to_string(route)}")
    end

    quote do
      unquote(__MODULE__).__runtime_path__(
        unquote(endpoint_ctx),
        unquote(router),
        unquote({:<<>>, meta, path_rewrite ++ query_rewrite})
      )
    end
  end
end
