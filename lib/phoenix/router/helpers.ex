defmodule Phoenix.Router.Helpers do
  # Module that generates the routing helpers.
  @moduledoc false

  alias Phoenix.Router.Route
  alias Plug.Conn

  @doc """
  Generates the helper module for the given environment and routes.
  """
  def define(env, routes) do
    # Ignore any route without helper or forwards.
    routes =
      Enum.reject(routes, fn {route, _exprs} ->
        is_nil(route.helper) or route.kind == :forward
      end)

    trailing_slash? = Enum.any?(routes, fn {route, _} -> route.trailing_slash? end)
    groups = Enum.group_by(routes, fn {route, _exprs} -> route.helper end)

    impls =
      for {_helper, helper_routes} <- groups,
          {_, [{route, exprs} | _]} <-
            helper_routes
            |> Enum.group_by(fn {route, exprs} -> [length(exprs.binding) | route.plug_opts] end)
            |> Enum.sort(),
          do: defhelper(route, exprs)

    catch_all = Enum.map(groups, &defhelper_catch_all/1)

    defhelper =
      quote generated: true, unquote: false do
        defhelper = fn helper, vars, opts, bins, segs, trailing_slash? ->
          def unquote(:"#{helper}_path")(
                conn_or_endpoint,
                unquote(Macro.escape(opts)),
                unquote_splicing(vars)
              ) do
            unquote(:"#{helper}_path")(
              conn_or_endpoint,
              unquote(Macro.escape(opts)),
              unquote_splicing(vars),
              []
            )
          end

          def unquote(:"#{helper}_path")(
                conn_or_endpoint,
                unquote(Macro.escape(opts)),
                unquote_splicing(vars),
                params
              )
              when is_list(params) or is_map(params) do
            path(
              conn_or_endpoint,
              segments(
                unquote(segs),
                params,
                unquote(bins),
                unquote(trailing_slash?),
                {unquote(helper), unquote(Macro.escape(opts)),
                 unquote(Enum.map(vars, &Macro.to_string/1))}
              )
            )
          end

          def unquote(:"#{helper}_url")(
                conn_or_endpoint,
                unquote(Macro.escape(opts)),
                unquote_splicing(vars)
              ) do
            unquote(:"#{helper}_url")(
              conn_or_endpoint,
              unquote(Macro.escape(opts)),
              unquote_splicing(vars),
              []
            )
          end

          def unquote(:"#{helper}_url")(
                conn_or_endpoint,
                unquote(Macro.escape(opts)),
                unquote_splicing(vars),
                params
              )
              when is_list(params) or is_map(params) do
            url(conn_or_endpoint) <>
              unquote(:"#{helper}_path")(
                conn_or_endpoint,
                unquote(Macro.escape(opts)),
                unquote_splicing(vars),
                params
              )
          end
        end
      end

    defcatch_all =
      quote generated: true, unquote: false do
        defcatch_all = fn helper, binding_lengths, params_lengths, routes ->
          for length <- binding_lengths do
            binding = List.duplicate({:_, [], nil}, length)
            arity = length + 2

            def unquote(:"#{helper}_path")(conn_or_endpoint, action, unquote_splicing(binding)) do
              path(conn_or_endpoint, "/")
              raise_route_error(unquote(helper), :path, unquote(arity), action, [])
            end

            def unquote(:"#{helper}_url")(conn_or_endpoint, action, unquote_splicing(binding)) do
              url(conn_or_endpoint)
              raise_route_error(unquote(helper), :url, unquote(arity), action, [])
            end
          end

          for length <- params_lengths do
            binding = List.duplicate({:_, [], nil}, length)
            arity = length + 2

            def unquote(:"#{helper}_path")(
                  conn_or_endpoint,
                  action,
                  unquote_splicing(binding),
                  params
                ) do
              path(conn_or_endpoint, "/")
              raise_route_error(unquote(helper), :path, unquote(arity + 1), action, params)
            end

            def unquote(:"#{helper}_url")(
                  conn_or_endpoint,
                  action,
                  unquote_splicing(binding),
                  params
                ) do
              url(conn_or_endpoint)
              raise_route_error(unquote(helper), :url, unquote(arity + 1), action, params)
            end
          end

          defp raise_route_error(unquote(helper), suffix, arity, action, params) do
            Phoenix.Router.Helpers.raise_route_error(
              __MODULE__,
              "#{unquote(helper)}_#{suffix}",
              arity,
              action,
              unquote(Macro.escape(routes)),
              params
            )
          end
        end
      end

    # It is in general bad practice to generate large chunks of code
    # inside quoted expressions. However, we can get away with this
    # here for two reasons:
    #
    # * Helper modules are quite uncommon, typically one per project.
    #
    # * We inline most of the code for performance, so it is specific
    #   per helper module anyway.
    #
    code =
      quote do
        @moduledoc false
        unquote(defhelper)
        unquote(defcatch_all)
        unquote_splicing(impls)
        unquote_splicing(catch_all)

        @doc """
        Generates the path information including any necessary prefix.
        """
        def path(data, path) do
          Phoenix.VerifiedRoutes.unverified_path(data, unquote(env.module), path)
        end

        @doc """
        Generates the connection/endpoint base URL without any path information.
        """
        def url(data) do
          Phoenix.VerifiedRoutes.unverified_url(data, "")
        end

        @doc """
        Generates path to a static asset given its file path.
        """
        def static_path(conn_or_endpoint_ctx, path) do
          Phoenix.VerifiedRoutes.static_path(conn_or_endpoint_ctx, path)
        end

        @doc """
        Generates url to a static asset given its file path.
        """
        def static_url(conn_or_endpoint_ctx, path) do
          Phoenix.VerifiedRoutes.static_url(conn_or_endpoint_ctx, path)
        end

        @doc """
        Generates an integrity hash to a static asset given its file path.
        """
        def static_integrity(conn_or_endpoint_ctx, path) do
          Phoenix.VerifiedRoutes.static_integrity(conn_or_endpoint_ctx, path)
        end

        # Functions used by generated helpers
        # Those are inlined here for performance

        defp to_param(int) when is_integer(int), do: Integer.to_string(int)
        defp to_param(bin) when is_binary(bin), do: bin
        defp to_param(false), do: "false"
        defp to_param(true), do: "true"
        defp to_param(data), do: Phoenix.Param.to_param(data)

        defp segments(segments, [], _reserved, trailing_slash?, _opts) do
          maybe_append_slash(segments, trailing_slash?)
        end

        defp segments(segments, query, reserved, trailing_slash?, _opts)
             when is_list(query) or is_map(query) do
          dict =
            for {k, v} <- query,
                (k = to_string(k)) not in reserved,
                do: {k, v}

          case Conn.Query.encode(dict, &to_param/1) do
            "" -> maybe_append_slash(segments, trailing_slash?)
            o -> maybe_append_slash(segments, trailing_slash?) <> "?" <> o
          end
        end

        if unquote(trailing_slash?) do
          defp maybe_append_slash("/", _), do: "/"
          defp maybe_append_slash(path, true), do: path <> "/"
        end

        defp maybe_append_slash(path, _), do: path
      end

    name = Module.concat(env.module, Helpers)
    Module.create(name, code, line: env.line, file: env.file)
    name
  end

  @doc """
  Receives a route and returns the quoted definition for its helper function.

  In case a helper name was not given, or route is forwarded, returns nil.
  """
  def defhelper(%Route{} = route, exprs) do
    helper = route.helper
    opts = route.plug_opts
    trailing_slash? = route.trailing_slash?

    {bins, vars} = :lists.unzip(exprs.binding)
    segs = expand_segments(exprs.path)

    quote do
      defhelper.(
        unquote(helper),
        unquote(Macro.escape(vars)),
        unquote(Macro.escape(opts)),
        unquote(Macro.escape(bins)),
        unquote(Macro.escape(segs)),
        unquote(Macro.escape(trailing_slash?))
      )
    end
  end

  def defhelper_catch_all({helper, routes_and_exprs}) do
    routes =
      routes_and_exprs
      |> Enum.map(fn {routes, exprs} ->
        {routes.plug_opts, Enum.map(exprs.binding, &elem(&1, 0))}
      end)
      |> Enum.sort()

    params_lengths =
      routes
      |> Enum.map(fn {_, bindings} -> length(bindings) end)
      |> Enum.uniq()

    # Each helper defines catch all like this:
    #
    #     def helper_path(context, action, ...binding)
    #     def helper_path(context, action, ...binding, params)
    #
    # Given the helpers are ordered by binding length, the additional
    # helper with param for a helper_path/n will always override the
    # binding for helper_path/n+1, so we skip those here to avoid warnings.
    binding_lengths = Enum.reject(params_lengths, &((&1 - 1) in params_lengths))

    quote do
      defcatch_all.(
        unquote(helper),
        unquote(binding_lengths),
        unquote(params_lengths),
        unquote(Macro.escape(routes))
      )
    end
  end

  @doc """
  Callback for generate router catch all.
  """
  def raise_route_error(mod, fun, arity, action, routes, params) do
    cond do
      is_atom(action) and not Keyword.has_key?(routes, action) ->
        "no action #{inspect(action)} for #{inspect(mod)}.#{fun}/#{arity}"
        |> invalid_route_error(fun, routes)

      is_list(params) or is_map(params) ->
        "no function clause for #{inspect(mod)}.#{fun}/#{arity} and action #{inspect(action)}"
        |> invalid_route_error(fun, routes)

      true ->
        invalid_param_error(mod, fun, arity, action, routes)
    end
  end

  defp invalid_route_error(prelude, fun, routes) do
    suggestions =
      for {action, bindings} <- routes do
        bindings = Enum.join([inspect(action) | bindings], ", ")
        "\n    #{fun}(conn_or_endpoint, #{bindings}, params \\\\ [])"
      end

    raise ArgumentError,
          "#{prelude}. The following actions/clauses are supported:\n#{suggestions}"
  end

  defp invalid_param_error(mod, fun, arity, action, routes) do
    call_vars = Keyword.fetch!(routes, action)

    raise ArgumentError, """
    #{inspect(mod)}.#{fun}/#{arity} called with invalid params.
    The last argument to this function should be a keyword list or a map.
    For example:

        #{fun}(#{Enum.join(["conn", ":#{action}" | call_vars], ", ")}, page: 5, per_page: 10)

    It is possible you have called this function without defining the proper
    number of path segments in your router.
    """
  end

  @doc """
  Callback for properly encoding parameters in routes.
  """
  def encode_param(str), do: URI.encode(str, &URI.char_unreserved?/1)

  defp expand_segments([]), do: "/"

  defp expand_segments(segments) when is_list(segments) do
    expand_segments(segments, "")
  end

  defp expand_segments(segments) do
    quote(do: "/" <> Enum.map_join(unquote(segments), "/", &unquote(__MODULE__).encode_param/1))
  end

  defp expand_segments([{:|, _, [h, t]}], acc),
    do:
      quote(
        do:
          unquote(expand_segments([h], acc)) <>
            "/" <> Enum.map_join(unquote(t), "/", &unquote(__MODULE__).encode_param/1)
      )

  defp expand_segments([h | t], acc) when is_binary(h),
    do: expand_segments(t, quote(do: unquote(acc) <> unquote("/" <> h)))

  defp expand_segments([h | t], acc),
    do:
      expand_segments(
        t,
        quote(do: unquote(acc) <> "/" <> unquote(__MODULE__).encode_param(to_param(unquote(h))))
      )

  defp expand_segments([], acc),
    do: acc
end
