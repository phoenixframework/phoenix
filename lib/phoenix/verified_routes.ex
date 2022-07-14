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

    verify_route(endpoint, router, route)
  end

  defmacro path(other), do: raise_invalid_route(other)

  defmacro path(endpoint, router, {:<<>>, _meta, _segments} = route) do
    verify_route(endpoint, router, route)
  end

  defmacro path(_endpoint, _router, other), do: raise_invalid_route(other)

  defmacro path(conn_or_socket_or_endpoint_or_uri, {:<<>>, _meta, _segments} = route) do
    %{router: router} = Module.get_attribute(__CALLER__.module, :phoenix_verified)
    verify_route(conn_or_socket_or_endpoint_or_uri, router, route)
  end

  defmacro path(_conn_or_socket_or_endpoint_or_uri, other), do: raise_invalid_route(other)

  defmacro sigil_p({:<<>>, _meta, _segments} = route, []) do
    %{router: router, endpoint: endpoint} =
      Module.get_attribute(__CALLER__.module, :phoenix_verified)

    verify_route(endpoint, router, route)
  end

  defmacro url(conn_or_socket_or_endpoint_or_uri, {:<<>>, _meta, _segments} = route) do
    %{router: router} = Module.get_attribute(__CALLER__.module, :phoenix_verified)
    rewrite_route = verify_route(conn_or_socket_or_endpoint_or_uri, router, route)

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
    conn
    |> build_own_forward_path(router, path)
    |> Kernel.||(build_conn_forward_path(conn, router, path))
    |> Kernel.||(path_with_script(path, conn.script_name))
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

  defp verify_route(endpoint_ctx, router, {:<<>>, meta, segments} = _route) do
    rewrite =
      Enum.map(segments, fn
        "/" ->
          "/"

        "/" <> _ = segment ->
          segment

        segment when is_binary(segment) ->
          raise ArgumentError, "path segments must begin with /"

        {:"::", m1, [{{:., m2, [Kernel, :to_string]}, m3, [dynamic]}, {:binary, m4, nil}]} ->
          {:"::", m1, [{{:., m2, [Phoenix.Param, :to_param]}, m3, [dynamic]}, {:binary, m4, nil}]}

        other ->
          raise ArgumentError,
                "verified routes require a compile-time string, got: #{inspect(other)}"
      end)

    test_path =
      Enum.map_join(rewrite, fn
        segment when is_binary(segment) -> segment
        _other -> "..."
      end)

    case Phoenix.Router.route_info(router, "GET", test_path, _host = nil) do
      %{} ->
        :ok

      :error ->
        IO.warn("""
        no route path for #{inspect(router)} matches "#{test_path}"

        Available routes:

        #{Phoenix.Router.ConsoleFormatter.format(router)}
        """)
    end

    quote do
      unquote(__MODULE__).__runtime_path__(
        unquote(endpoint_ctx),
        unquote(router),
        unquote({:<<>>, meta, rewrite})
      )
    end
  end

  defp build_own_forward_path(conn, router, path) do
    case Map.fetch(conn.private, router) do
      {:ok, {local_script, _}} ->
        path_with_script(path, local_script)

      :error ->
        nil
    end
  end

  defp build_conn_forward_path(
         %Plug.Conn{private: %{phoenix_router: phx_router}} = conn,
         router,
         path
       ) do
    case Map.fetch(conn.private, phx_router) do
      {:ok, {script_name, forwards}} ->
        case Map.fetch(forwards, router) do
          {:ok, local_script} ->
            path_with_script(path, script_name ++ local_script)

          :error ->
            nil
        end

      :error ->
        nil
    end
  end

  defp build_conn_forward_path(_conn, _router, _path), do: nil

  defp path_with_script(path, []) do
    path
  end

  defp path_with_script(path, script) do
    "/" <> Enum.join(script, "/") <> path
  end
end
