defmodule Phoenix.VerifiedRoutes do
  @moduledoc ~S"""
  TODO
    - [ ] ~p"/posts?page=#{page}"

  use Phoenix.VerifiedRoutes,
    router: AppWeb.Router,
    endpoint: AppWeb.Endpoint,
    statics: ~(images)
  """
  @doc false
  defstruct router: nil,
            route: nil,
            inspected_route: nil,
            stacktrace: nil,
            test_path: nil

  defmacro __using__(opts) do
    opts =
      if Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, __CALLER__))
      else
        opts
      end

    quote do
      unquote(__MODULE__).__using__(__MODULE__, unquote(opts))
      import unquote(__MODULE__)
    end
  end

  @doc false
  def __using__(mod, opts) do
    Module.register_attribute(mod, :phoenix_verified_routes, accumulate: true)
    Module.put_attribute(mod, :before_compile, __MODULE__)
    Module.put_attribute(mod, :router, Keyword.fetch!(opts, :router))
    Module.put_attribute(mod, :endpoint, Keyword.get(opts, :endpoint))
    Module.put_attribute(mod, :phoenix_verified_statics, Keyword.get(opts, :statics))
  end

  defmacro __before_compile__(env) do
    if Version.match?(System.version(), ">= 1.14.0-dev") do
      quote do
        @after_verify {__MODULE__, :__verify_routes__}

        @doc false
        def __verify_routes__(_module) do
          unquote(__MODULE__).__verify__(@phoenix_verified_routes)
        end
      end
    else
      __verify__(Module.get_attribute(env.module, :phoenix_verified_routes))
    end
  end

  @doc false
  def __verify__(routes) when is_list(routes) do
    Enum.each(routes, fn %__MODULE__{} = route ->
      unless match_route?(route.router, route.test_path) do
        IO.warn(
          "no route path for #{inspect(route.router)} matches #{route.inspected_route}",
          route.stacktrace
        )
      end
    end)
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:path, 2}})

  defp expand_alias(other, _env), do: other

  @doc ~S'''
  Generates the router path with route verification.

  Interpolated named parameters are encoded via the `Phoenix.Param` protocol.

  Warns when the provided path does not match against the router specified
  in `use Phoenix.VerifiedRoutes` or the `@router` module attribute.

  ## Examples

      use Phoenix.VerifiedRoutes, endpoint: MyAppWeb.Endpoint, router: MyAppWeb.Router

      redirect(to: ~p"/users/top")

      redirect(to: ~p"/users/#{@user}")

      ~H"""
      <.link to={~p"/users?#{[page: @page]}"}>profile</.link>
      """
  '''
  defmacro sigil_p({:<<>>, _meta, _segments} = route, extra) do
    validate_sigil_p!(extra)
    endpoint = attr!(__CALLER__, :endpoint)
    router = attr!(__CALLER__, :router)

    route
    |> build_route(route, __CALLER__, endpoint, router)
    |> inject_path(__CALLER__)
  end

  defp inject_path(
         {%__MODULE__{} = route, type, _endpoint_ctx, _route_ast, path_ast, static_ast},
         env
       ) do
    case type do
      :static ->
        static_ast

      other when other in [:match, :error] ->
        Module.put_attribute(env.module, :phoenix_verified_routes, route)
        path_ast
    end
  end

  defp inject_url(
         {%__MODULE__{} = route, type, endpoint_ctx, route_ast, path_ast, _static_ast},
         env
       ) do
    case type do
      :static ->
        quote do
          unquote(__MODULE__).static_url(unquote_splicing([endpoint_ctx, route_ast]))
        end

      other when other in [:match, :error] ->
        Module.put_attribute(env.module, :phoenix_verified_routes, route)

        quote do
          unquote(__MODULE__).unverified_url(unquote_splicing([endpoint_ctx, path_ast]))
        end
    end
  end

  defp validate_sigil_p!([]), do: :ok

  defp validate_sigil_p!(extra) do
    raise ArgumentError, "~p does not support trailing fragment, got: #{inspect(extra)}"
  end

  defp raise_invalid_route(ast) do
    raise ArgumentError,
          "expected compile-time ~p path string, got: #{Macro.to_string(ast)}\n" <>
            "Use unverified_path/2 and unverified_url/2 if you need to build an arbitrary path."
  end

  @doc ~S'''
  Generates the router path with route verification.

  See `sigil_p/1` for more information.

  Warns when the provided path does not match against the router specified
  in `use Phoenix.VerifiedRoutes` or the `@router` module attribute.

  ## Examples

      use Phoenix.VerifiedRoutes, endpoint: MyAppWeb.Endpoint, router: MyAppWeb.Router

      redirect(to: path(conn, ~p"/users/top"))

      redirect(to: path(conn, ~p"/users/#{@user}"))

      ~H"""
      <.link to={path(@uri, "/users?#{[page: @page]}")}>profile</.link>
      """
  '''
  defmacro path(
             endpoint,
             router,
             {:sigil_p, _, [{:<<>>, _meta, _segments} = route, extra]} = og_ast
           ) do
    validate_sigil_p!(extra)

    route
    |> build_route(og_ast, __CALLER__, endpoint, router)
    |> inject_path(__CALLER__)
  end

  defmacro path(_endpoint, _router, other), do: raise_invalid_route(other)

  defmacro path(
             conn_or_socket_or_endpoint_or_uri,
             {:sigil_p, _, [{:<<>>, _meta, _segments} = route, extra]} = og_ast
           ) do
    validate_sigil_p!(extra)
    router = attr!(__CALLER__, :router)

    route
    |> build_route(og_ast, __CALLER__, conn_or_socket_or_endpoint_or_uri, router)
    |> inject_path(__CALLER__)
  end

  defmacro path(conn_or_socket_or_endpoint_or_uri, {:sigil_p, _, [route, extra]} = og_ast)
           when is_binary(route) do
    validate_sigil_p!(extra)
    router = attr!(__CALLER__, :router)

    route
    |> build_route(og_ast, __CALLER__, conn_or_socket_or_endpoint_or_uri, router)
    |> inject_path(__CALLER__)
  end

  defmacro path(_conn_or_socket_or_endpoint_or_uri, other), do: raise_invalid_route(other)

  @doc ~S'''
  Generates the router url with route verification.

  See `sigil_p/1` for more information.

  Warns when the provided path does not match against the router specified
  in `use Phoenix.VerifiedRoutes` or the `@router` module attribute.

  ## Examples

      use Phoenix.VerifiedRoutes, endpoint: MyAppWeb.Endpoint, router: MyAppWeb.Router

      redirect(to: path(conn, ~p"/users/top"))

      redirect(to: path(conn, ~p"/users/#{@user}"))

      ~H"""
      <.link to={path(@uri, "/users?#{[page: @page]}")}>profile</.link>
      """
  '''
  defmacro url({:sigil_p, _, [{:<<>>, _meta, _segments} = route, _]} = og_ast) do
    endpoint = attr!(__CALLER__, :endpoint)
    router = attr!(__CALLER__, :router)

    route
    |> build_route(og_ast, __CALLER__, endpoint, router)
    |> inject_url(__CALLER__)
  end

  defmacro url({:sigil_p, _, [route, _]} = og_ast) when is_binary(route) do
    endpoint = attr!(__CALLER__, :endpoint)
    router = attr!(__CALLER__, :router)

    route
    |> build_route(og_ast, __CALLER__, endpoint, router)
    |> inject_url(__CALLER__)
  end

  defmacro url(other), do: raise_invalid_route(other)

  defmacro url(
             conn_or_socket_or_endpoint_or_uri,
             {:sigil_p, _, [{:<<>>, _meta, _segments} = route, _]} = og_ast
           ) do
    router = attr!(__CALLER__, :router)

    route
    |> build_route(og_ast, __CALLER__, conn_or_socket_or_endpoint_or_uri, router)
    |> inject_url(__CALLER__)
  end

  defmacro url(conn_or_socket_or_endpoint_or_uri, {:sigil_p, _, [route, _]} = og_ast)
           when is_binary(route) do
    router = attr!(__CALLER__, :router)

    route
    |> build_route(og_ast, __CALLER__, conn_or_socket_or_endpoint_or_uri, router)
    |> inject_url(__CALLER__)
  end

  defmacro url(_conn_or_socket_or_endpoint_or_uri, other), do: raise_invalid_route(other)

  @doc """
  Generates url to a static asset given its file path.
  """
  def static_url(%Plug.Conn{private: private}, path) do
    case private do
      %{phoenix_static_url: static_url} -> concat_url(static_url, path)
      %{phoenix_endpoint: endpoint} -> static_url(endpoint, path)
    end
  end

  def static_url(%_{endpoint: endpoint}, path) do
    static_url(endpoint, path)
  end

  def static_url(endpoint, path) when is_atom(endpoint) do
    endpoint.static_url() <> endpoint.static_path(path)
  end

  def static_url(other, path) do
    raise ArgumentError,
          "expected a %Plug.Conn{}, a %Phoenix.Socket{}, a %URI{}, a struct with an :endpoint key, " <>
            "or a Phoenix.Endpoint when building static url for #{path}, got: #{inspect(other)}"
  end

  @doc """
  Returns the URL for the endpoint from the path without verification.
  """
  def unverified_url(%Plug.Conn{private: private}, path) do
    case private do
      %{phoenix_router_url: url} when is_binary(url) -> concat_url(url, path)
      %{phoenix_endpoint: endpoint} -> concat_url(endpoint.url(), path)
    end
  end

  def unverified_url(%_{endpoint: endpoint}, path) do
    concat_url(endpoint.url(), path)
  end

  def unverified_url(%URI{} = uri, path) do
    URI.to_string(%{uri | path: path})
  end

  def unverified_url(endpoint, path) when is_atom(endpoint) do
    concat_url(endpoint.url(), path)
  end

  def unverified_url(other, path) do
    raise ArgumentError,
          "expected a %Plug.Conn{}, a %Phoenix.Socket{}, a %URI{}, a struct with an :endpoint key, " <>
            "or a Phoenix.Endpoint when building url at #{path}, got: #{inspect(other)}"
  end

  defp concat_url(url, path) when is_binary(path), do: url <> path

  @doc """
  Generates path to a static asset given its file path.
  """
  def static_path(%Plug.Conn{private: private}, path) do
    case private do
      %{phoenix_static_url: _} -> path
      %{phoenix_endpoint: endpoint} -> endpoint.static_path(path)
    end
  end

  def static_path(%URI{} = uri, path) do
    (uri.path || "") <> path
  end

  def static_path(%_{endpoint: endpoint}, path) do
    static_path(endpoint, path)
  end

  def static_path(endpoint, path) when is_atom(endpoint) do
    endpoint.static_path(path)
  end

  @doc """
  Returns the path with relevant script name prefixes without verification.
  """
  def unverified_path(%Plug.Conn{} = conn, router, path) do
    conn
    |> build_own_forward_path(router, path)
    |> Kernel.||(build_conn_forward_path(conn, router, path))
    |> Kernel.||(path_with_script(path, conn.script_name))
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

  @doc false
  def __encode_segment__(data) do
    case data do
      [] -> ""
      [str | _] when is_binary(str) -> Enum.map_join(data, "/", &encode_segment/1)
      _ -> encode_segment(data)
    end
  end

  defp encode_segment(data) do
    data
    |> Phoenix.Param.to_param()
    |> URI.encode(&URI.char_unreserved?/1)
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
           {:"::", m1, [{{:., m2, [Kernel, :to_string]}, m3, [dynamic]}, {:binary, _, _} = bin]}
           | rest
         ],
         route,
         acc
       ) do
    rewrite = {:"::", m1, [{{:., m2, [__MODULE__, :__encode_segment__]}, m3, [dynamic]}, bin]}

    verify_segment(rest, route, [rewrite | acc])
  end

  defp verify_segment([_other | _], route, _acc) do
    raise ArgumentError,
          "verified routes require a compile-time string, got: #{Macro.to_string(route)}"
  end

  # we've reached the end of the path without finding query, return to caller
  defp verify_segment([], _route, acc), do: {Enum.reverse(acc), _query = []}

  defp verify_query(
         [{:"::", m1, [{{:., m2, [Kernel, :to_string]}, m2, [arg]}, {:binary, _, _} = bin]}],
         _route
       ) do
    {:"::", m1, [{{:., m2, [__MODULE__, :__encode_query__]}, m2, [arg]}, bin]}
  end

  defp verify_query(_other, route) do
    raise_invalid_query(route)
  end

  defp raise_invalid_query(route) do
    raise ArgumentError,
          "expected query string param to be compile-time map or keyword list, got: #{Macro.to_string(route)}"
  end

  @doc """
  Generates an integrity hash to a static asset given its file path.
  """
  def static_integrity(%Plug.Conn{private: %{phoenix_endpoint: endpoint}}, path) do
    static_integrity(endpoint, path)
  end

  def static_integrity(%_{endpoint: endpoint}, path) do
    static_integrity(endpoint, path)
  end

  def static_integrity(endpoint, path) when is_atom(endpoint) do
    endpoint.static_integrity(path)
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

  defp route_type(router, statics, test_path) do
    cond do
      static_path?(test_path, statics) -> :static
      match_route?(router, test_path) -> :match
      true -> :error
    end
  end

  defp match_route?(router, test_path) when is_binary(test_path) do
    split_path = for segment <- String.split(test_path, "/"), segment != "", do: segment
    match_route?(router, split_path)
  end

  defp match_route?(router, split_path) when is_list(split_path) do
    case router.__match_route__(split_path) do
      {nil = _forward_plug, _} -> true
      {forward_plug, _} -> match_forward_route?(router, forward_plug, split_path)
      :error -> false
    end
  end

  defp match_forward_route?(router, forward_router, split_path) do
    if function_exported?(forward_router, :__routes__, 0) do
      script_name = router.__forward__(forward_router)
      match_route?(forward_router, split_path -- script_name)
    else
      true
    end
  end

  defp build_route(route_ast, og_ast, env, endpoint_ctx, router) do
    statics = Module.get_attribute(env.module, :phoenix_verified_statics, [])

    router =
      case Macro.expand(router, env) do
        mod when is_atom(mod) -> mod
        other -> raise ArgumentError, """
        expected router to be to module, got: #{inspect(other)}

        If you want to generate a compile-time router, use unverified_path/2 instead.
        """
      end

    statics =
      case Macro.expand(statics, env) do
        list when is_list(list) -> list
        other -> raise ArgumentError, "expected statics to be a list, got: #{inspect(other)}"
      end

    {type, test_path, path_ast, static_ast} =
      rewrite_path(route_ast, endpoint_ctx, router, statics)

    route = %__MODULE__{
      router: router,
      stacktrace: Macro.Env.stacktrace(env),
      inspected_route: Macro.to_string(og_ast),
      test_path: test_path
    }

    {route, type, endpoint_ctx, route_ast, path_ast, static_ast}
  end

  defp rewrite_path(route, endpoint, router, statics) do
    {rewrite_route, test_path} =
      case route do
        route when is_binary(route) ->
          test_path =
            case String.split(route, "?") do
              [^route] -> route
              [prefix, _query] -> prefix
              _ -> raise ArgumentError, "invalid query string for path #{route}"
            end

          {route, test_path}

        {:<<>>, meta, segments} = route ->
          {path_rewrite, query_rewrite} = verify_segment(segments, route, [])
          test_path = Enum.map_join(path_rewrite, &if(is_binary(&1), do: &1, else: "1"))
          {{:<<>>, meta, path_rewrite ++ query_rewrite}, test_path}
      end

    type = route_type(router, statics, test_path)

    path_ast =
      quote do
        unquote(__MODULE__).unverified_path(unquote_splicing([endpoint, router, rewrite_route]))
      end

    static_ast =
      quote do
        unquote(__MODULE__).static_path(unquote_splicing([endpoint, rewrite_route]))
      end

    {type, test_path, path_ast, static_ast}
  end

  defp attr!(env, :endpoint) do
    Module.get_attribute(env.module, :endpoint) ||
      raise """
      expected @endpoint to be set. For dynamic endpoint resolution, use path/2 instead.

      for example:

          path(conn_or_socket, ~p"/my-path")
      """
  end

  defp attr!(env, name) do
    Module.get_attribute(env.module, name) || raise "expected @#{name} module attribute to be set"
  end

  defp static_path?(path, statics) do
    Enum.find(statics, &String.starts_with?(path, "/" <> &1))
  end

  defp build_own_forward_path(conn, router, path) do
    case conn.private do
      %{^router => local_script} when is_list(local_script) ->
        path_with_script(path, local_script)

      %{} ->
        nil
    end
  end

  defp build_conn_forward_path(%Plug.Conn{} = conn, router, path) do
    with %{phoenix_router: phx_router} <- conn.private,
         %{^phx_router => script_name} when is_list(script_name) <- conn.private,
         local_script when is_list(local_script) <- phx_router.__forward__(router) do
      path_with_script(path, script_name ++ local_script)
    else
      _ -> nil
    end
  end

  defp path_with_script(path, []), do: path
  defp path_with_script(path, script), do: "/" <> Enum.join(script, "/") <> path
end
