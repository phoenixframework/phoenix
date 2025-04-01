defmodule Phoenix.VerifiedRoutes do
  @moduledoc ~S'''
  Provides route generation with compile-time verification.

  Use of the `sigil_p` macro allows paths and URLs throughout your
  application to be compile-time verified against your Phoenix router(s).
  For example, the following path and URL usages:

      ~H"""
      <.link href={~p"/sessions/new"} method="post">Log in</.link>
      """

      redirect(to: url(~p"/posts/#{post}"))

  Will be verified against your standard `Phoenix.Router` definitions:

      get "/posts/:post_id", PostController, :show
      post "/sessions/new", SessionController, :create

  Unmatched routes will issue compiler warnings:

  ```console
  warning: no route path for AppWeb.Router matches "/postz/#{post}"
    lib/app_web/controllers/post_controller.ex:100: AppWeb.PostController.show/2
  ```

  Additionally, interpolated ~p values are encoded via the `Phoenix.Param` protocol.
  For example, a `%Post{}` struct in your application may derive the `Phoenix.Param`
  protocol to generate slug-based paths rather than ID based ones. This allows you to
  use `~p"/posts/#{post}"` rather than `~p"/posts/#{post.slug}"` throughout your
  application. See the `Phoenix.Param` documentation for more details.

  Finally, query strings are also supported in verified routes, either in traditional form:

      ~p"/posts?page=#{page}"

  Or as a keyword list or map of values:

      params = %{page: 1, direction: "asc"}
      ~p"/posts?#{params}"

  Like path segments, query strings params are proper URL encoded and may be interpolated
  directly into the ~p string.

  ## What about named routes?

  Many web frameworks, and early versions of Phoenix, provided a feature called "named routes".
  The idea is that, when you define routes in your web applications, you could give them names
  too. In Phoenix that was done as follows:

      get "/login", SessionController, :create, as: :login

  And now you could generate the route using the `login_path` function.

  Named routes exist to avoid hardcoding routes in your templates, if you wrote `<a href="/login">`
  and then changed your router, the link would point to a page that no longer exist. By using
  `login_path`, we make sure it always points to a valid URL in our router. However, named routes
  come with the downsides of indirection: when you look at the code, it is not immediately clear
  which URL will be generated. Furthermore, if you have an existing URL and you want to add it
  to a template, you need to do a reverse lookup and find its name in the router. At the end of
  the day, named routes are arbitrary names that need to be memorized by developers, adding
  cognitive overhead.

  Verified routes tackle this problem by allowing the routes to be written as we would read them
  in a browser, but using the `~p` sigil to guarantee they actually exist at compilation time.
  They remove the indirection of named routes while keeping their guarantees.

  In any case, if part of your application requires features similar to named routes, then
  remember you can still leverage Elixir features to achieve the same result. For example,
  you can define several functions as named routes to be reused across modules:

      def login_path, do: ~p"/login"
      def user_home_path(user), do: ~p"/users/#{user.username}"

  ## Options

  To verify routes in your application modules, such as controller, templates, and views,
  `use Phoenix.VerifiedRoutes`, which supports the following options:

    * `:router` - The required router to verify `~p` paths against
    * `:endpoint` - Optional endpoint for URL generation
    * `:statics` - Optional list of static directories to treat as verified paths
    * `:path_prefixes` - Optional list of path prefixes to be added to every generated path.
      See "Path prefixes" for more information

  For example:

      use Phoenix.VerifiedRoutes,
        router: AppWeb.Router,
        endpoint: AppWeb.Endpoint,
        statics: ~w(images)

  ## Connection/socket-based route generation

  The majority of path and URL generation needs your application will be met
  with `~p` and `url/1`, where all information necessary to construct the path
  or URL is provided by the compile-time information stored in the Endpoint
  and Router passed to `use Phoenix.VerifiedRoutes`.

  That said, there are some circumstances where `path/2`, `path/3`, `url/2`, and `url/3`
  are required:

    * When the runtime values of the `%Plug.Conn{}`, `%Phoenix.LiveSocket{}`, or a `%URI{}`
      dictate the formation of the path or URL, which happens under the following scenarios:

      - `Phoenix.Controller.put_router_url/2` is used to override the endpoint's URL
      - `Phoenix.Controller.put_static_url/2` is used to override the endpoint's static URL

    * When the Router module differs from the one passed to `use Phoenix.VerifiedRoutes`,
      such as library code, or application code that relies on multiple routers. In such cases,
      the router module can be provided explicitly to `path/3` and `url/3`.

  ## Tracking warnings

  All static path segments must start with forward slash, and you must have a static segment
  between dynamic interpolations in order for a route to be verified without warnings.
  For example, imagine you have these two routes:

      get "/media/posts/:id"
      get "/media/images/:id"

  The following route will be verified and emit a warning as it does not match the router:

      ~p"/media/post/#{post}"

  However the one below will not, the "post" segment is dynamic:

      type = "post"
      ~p"/media/#{type}/#{post}"

  If you find yourself needing to generate dynamic URLs which are defined statically
  in the router, that's a good indicator you should refactor it into one or more
  function, such as `posts_path/1` and `images_path/1`.

  Like any other compilation warning, the Elixir compiler will warn any time the file
  that a `~p` resides in changes, or if the router is changed.

  ## Localized routes and path prefixes

  Applications that need to support internationalization (i18n) and localization (l10n)
  often do so at the URL level. In such cases, there are different approaches one can
  choose.

  One option is to perform i18n at the domain level. You can have `example.com` (in which
  you would detect the locale based on the "Accept-Language" HTTP header), `en.example.com`,
  `en-GB.example.com` and so forth. In this case, you would have a plug that looks at the
  host and at HTTP headers and calls `Gettext.get_locale/1` accordingly. The biggest benefit
  of this approach is that you don't have to change the routes in your application and
  verified routes works as is.

  Some applications, however, like to add the locale as part of the URL prefix:

      scope "/:locale" do
        get "/posts"
        get "/images"
      end

  For such cases, VerifiedRoutes allow you to configure a `path_prefixes` option, which
  is a list of segments to prepend to the URL. For example:

      use Phoenix.VerifiedRoutes,
        router: AppWeb.Router,
        endpoint: AppWeb.Endpoint,
        path_prefixes: [{Gettext, :get_locale, []}]

  The above will prepend `"/#{Gettext.get_locale()}"` to every path and url generated with
  `~p`. If your website has a handful of URLs that do not require the locale prefix, then
  we suggest defining them in a separate module, where you use `Phoenix.VerifiedRoutes`
  without the prefix option:

      defmodule UnlocalizedRoutes do
        use Phoenix.VerifiedRoutes,
          router: AppWeb.Router,
          endpoint: AppWeb.Endpoint,

        # Since :path_prefixes was not declared,
        # the code below won't prepend the locale and still be verified
        def root, do: ~p"/"
      end

  Finally, for even more complex use cases, where the whole URL needs to localized,
  see projects such as [`routex`](https://hex.pm/packages/routex) and
  [`ex_cldr_routes`](https://hex.pm/packages/ex_cldr_routes).

  ## Usage with custom plugs

  Sometimes, when we want to do dynamic routing, we will forward to custom plugs.
  It is possible to make these dynamic routers support `mix phx.routes` and verified
  routes at compile time by adopting the `Phoenix.VerifiedRoutes` behaviour.
  For example:

      defmodule MyApp.LocaleRouter do
        use Plug.Router
        @behaviour Phoenix.VerifiedRoutes

        # custom routing rules

        # for displaying in `mix phx.routes`
        def formatted_routes(plug_opts) do
          for locale <- supported_locales(plug_opts) do
            %{verb: "GET", path: "/#{locale}/*subpath"}
          end
        end

        def verified_route?(plug_opts, path) do
          plug_opts
          |> supported_locales()
          |> Enum.any?(fn locale ->
            Enum.at(path, 0) == locale
          end)
        end
      end
  '''
  @doc false
  defstruct router: nil,
            route: nil,
            inspected_route: nil,
            warn_location: nil,
            test_path: nil

  defmacro __using__(opts) do
    opts =
      if Keyword.keyword?(opts) do
        for {k, v} <- opts do
          if Macro.quoted_literal?(v) do
            {k, Macro.prewalk(v, &expand_alias(&1, __CALLER__))}
          else
            {k, v}
          end
        end
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

    statics =
      case Keyword.get(opts, :statics, []) do
        list when is_list(list) -> list
        other -> raise ArgumentError, "expected statics to be a list, got: #{inspect(other)}"
      end

    path_prefixes =
      case Keyword.get(opts, :path_prefixes, []) do
        list when is_list(list) ->
          list

        other ->
          raise ArgumentError,
                "expected path_prefixes to be a list of zero-arity functions, got: #{inspect(other)}"
      end

    Module.put_attribute(mod, :phoenix_verified_config, %{
      statics: statics,
      path_prefixes: path_prefixes
    })
  end

  @type plug_opts :: any()
  @type formatted_route :: %{
          required(:verb) => String.t(),
          required(:path) => String.t(),
          required(:label) => String.t()
        }

  @doc """
  Returns the necessary information about routes for display in `mix phx.routes`.

  The `plug_opts` is typically only passed when the router is mounted within
  a `Phoenix.Router`. Otherwise it defaults to `[]`.
  """
  @callback formatted_routes(plug_opts()) :: [formatted_route()]

  @doc """
  Returns `true` if the path is verified, and false if not.

  The `plug_opts` is typically only passed when the router is mounted within
  a `Phoenix.Router`. Otherwise it defaults to `[]`.
  """
  @callback verified_route?(plug_opts(), [String.t()]) :: boolean()

  @after_verify_supported Version.match?(System.version(), ">= 1.14.0")

  defmacro __before_compile__(_env) do
    if @after_verify_supported do
      quote do
        @after_verify {__MODULE__, :__phoenix_verify_routes__}

        @doc false
        def __phoenix_verify_routes__(_module) do
          unquote(__MODULE__).__verify__(@phoenix_verified_routes)
        end
      end
    end
  end

  @doc false
  def __verify__(routes) when is_list(routes) do
    Enum.each(routes, fn %__MODULE__{} = route ->
      test_path = split_test_path(route.test_path)

      unless route.router.verified_route?([], test_path) do
        IO.warn(
          "no route path for #{inspect(route.router)} matches #{route.inspected_route}",
          route.warn_location
        )
      end
    end)
  end

  defp split_test_path(test_path) do
    test_path
    |> String.split("#")
    |> Enum.at(0)
    |> String.split("/")
    |> Enum.filter(fn segment -> segment != "" end)
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
      <.link href={~p"/users?page=#{@page}"}>profile</.link>

      <.link href={~p"/users?#{@params}"}>profile</.link>
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
         {%__MODULE__{} = route, static?, _endpoint_ctx, _route_ast, path_ast, static_ast},
         env
       ) do
    if static? do
      static_ast
    else
      Module.put_attribute(env.module, :phoenix_verified_routes, route)
      path_ast
    end
  end

  defp inject_url(
         {%__MODULE__{} = route, static?, endpoint_ctx, route_ast, path_ast, _static_ast},
         env
       ) do
    if static? do
      quote do
        unquote(__MODULE__).static_url(unquote_splicing([endpoint_ctx, route_ast]))
      end
    else
      Module.put_attribute(env.module, :phoenix_verified_routes, route)

      quote do
        unquote(__MODULE__).unverified_url(unquote_splicing([endpoint_ctx, path_ast]))
      end
    end
  end

  defp validate_sigil_p!([]), do: :ok

  defp validate_sigil_p!(extra) do
    raise ArgumentError, "~p does not support modifiers after closing, got: #{extra}"
  end

  defp raise_invalid_route(ast) do
    raise ArgumentError,
          "expected compile-time ~p path string, got: #{Macro.to_string(ast)}\n" <>
            "Use unverified_path/2 and unverified_url/2 if you need to build an arbitrary path."
  end

  @doc ~S'''
  Generates the router path with route verification.

  See `sigil_p/2` for more information.

  Warns when the provided path does not match against the router specified
  in the router argument.

  ## Examples

      import Phoenix.VerifiedRoutes

      redirect(to: path(conn, MyAppWeb.Router, ~p"/users/top"))

      redirect(to: path(conn, MyAppWeb.Router, ~p"/users/#{@user}"))

      ~H"""
      <.link href={path(@uri, MyAppWeb.Router, "/users?page=#{@page}")}>profile</.link>
      <.link href={path(@uri, MyAppWeb.Router, "/users?#{@params}")}>profile</.link>
      """
  '''
  defmacro path(
             conn_or_socket_or_endpoint_or_uri,
             router,
             {:sigil_p, _, [{:<<>>, _meta, _segments} = route, extra]} = sigil_p
           ) do
    validate_sigil_p!(extra)

    route
    |> build_route(sigil_p, __CALLER__, conn_or_socket_or_endpoint_or_uri, router)
    |> inject_path(__CALLER__)
  end

  defmacro path(_endpoint, _router, other), do: raise_invalid_route(other)

  @doc ~S'''
  Generates the router path with route verification.

  See `sigil_p/2` for more information.

  Warns when the provided path does not match against the router specified
  in `use Phoenix.VerifiedRoutes` or the `@router` module attribute.

  ## Examples

      import Phoenix.VerifiedRoutes

      redirect(to: path(conn, ~p"/users/top"))

      redirect(to: path(conn, ~p"/users/#{@user}"))

      ~H"""
      <.link href={path(@uri, "/users?page=#{@page}")}>profile</.link>
      <.link href={path(@uri, "/users?#{@params}")}>profile</.link>
      """
  '''
  defmacro path(
             conn_or_socket_or_endpoint_or_uri,
             {:sigil_p, _, [{:<<>>, _meta, _segments} = route, extra]} = sigil_p
           ) do
    validate_sigil_p!(extra)
    router = attr!(__CALLER__, :router)

    route
    |> build_route(sigil_p, __CALLER__, conn_or_socket_or_endpoint_or_uri, router)
    |> inject_path(__CALLER__)
  end

  defmacro path(_conn_or_socket_or_endpoint_or_uri, other), do: raise_invalid_route(other)

  @doc ~S'''
  Generates the router url with route verification.

  See `sigil_p/2` for more information.

  Warns when the provided path does not match against the router specified
  in `use Phoenix.VerifiedRoutes` or the `@router` module attribute.

  ## Examples

      use Phoenix.VerifiedRoutes, endpoint: MyAppWeb.Endpoint, router: MyAppWeb.Router

      redirect(to: url(conn, ~p"/users/top"))

      redirect(to: url(conn, ~p"/users/#{@user}"))

      ~H"""
      <.link href={url(@uri, "/users?#{[page: @page]}")}>profile</.link>
      """

  The router may also be provided in cases where you want to verify routes for a
  router other than the one passed to `use Phoenix.VerifiedRoutes`:

      redirect(to: url(conn, OtherRouter, ~p"/users"))

  Forwarded routes are also resolved automatically. For example, imagine you
  have a forward path to an admin router in your main router:

      defmodule AppWeb.Router do
        ...
        forward "/admin", AppWeb.AdminRouter
      end

      defmodule AppWeb.AdminRouter do
        ...
        get "/users", AppWeb.Admin.UserController
      end

  Forwarded paths in your main application router will be verified as usual,
  such as `~p"/admin/users"`.
  '''
  defmacro url({:sigil_p, _, [{:<<>>, _meta, _segments} = route, _]} = sigil_p) do
    endpoint = attr!(__CALLER__, :endpoint)
    router = attr!(__CALLER__, :router)

    route
    |> build_route(sigil_p, __CALLER__, endpoint, router)
    |> inject_url(__CALLER__)
  end

  defmacro url(other), do: raise_invalid_route(other)

  @doc """
  Generates the router url with route verification from the connection, socket, or URI.

  See `url/1` for more information.
  """
  defmacro url(
             conn_or_socket_or_endpoint_or_uri,
             {:sigil_p, _, [{:<<>>, _meta, _segments} = route, _]} = sigil_p
           ) do
    router = attr!(__CALLER__, :router)

    route
    |> build_route(sigil_p, __CALLER__, conn_or_socket_or_endpoint_or_uri, router)
    |> inject_url(__CALLER__)
  end

  defmacro url(_conn_or_socket_or_endpoint_or_uri, other), do: raise_invalid_route(other)

  @doc """
  Generates the url with route verification from the connection, socket, or URI and router.

  See `url/1` for more information.
  """
  defmacro url(
             conn_or_socket_or_endpoint_or_uri,
             router,
             {:sigil_p, _, [{:<<>>, _meta, _segments} = route, _]} = sigil_p
           ) do
    router = Macro.expand(router, __CALLER__)

    route
    |> build_route(sigil_p, __CALLER__, conn_or_socket_or_endpoint_or_uri, router)
    |> inject_url(__CALLER__)
  end

  defmacro url(_conn_or_socket_or_endpoint_or_uri, _router, other), do: raise_invalid_route(other)

  @doc """
  Generates url to a static asset given its file path.

  See `c:Phoenix.Endpoint.static_url/0` and `c:Phoenix.Endpoint.static_path/1` for more information.

  ## Examples

      iex> static_url(conn, "/assets/js/app.js")
      "https://example.com/assets/js/app-813dfe33b5c7f8388bccaaa38eec8382.js"

      iex> static_url(socket, "/assets/js/app.js")
      "https://example.com/assets/js/app-813dfe33b5c7f8388bccaaa38eec8382.js"

      iex> static_url(AppWeb.Endpoint, "/assets/js/app.js")
      "https://example.com/assets/js/app-813dfe33b5c7f8388bccaaa38eec8382.js"
  """
  def static_url(conn_or_socket_or_endpoint, path)

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
          "expected a %Plug.Conn{}, a %Phoenix.Socket{}, a struct with an :endpoint key, " <>
            "or a Phoenix.Endpoint when building static url for #{path}, got: #{inspect(other)}"
  end

  @doc """
  Returns the URL for the endpoint from the path without verification.

  ## Examples

      iex> unverified_url(conn, "/posts")
      "https://example.com/posts"

      iex> unverified_url(conn, "/posts", page: 1)
      "https://example.com/posts?page=1"
  """
  def unverified_url(conn_or_socket_or_endpoint_or_uri, path, params \\ %{})
      when (is_map(params) or is_list(params)) and is_binary(path) do
    guarded_unverified_url(conn_or_socket_or_endpoint_or_uri, path, params)
  end

  defp guarded_unverified_url(%Plug.Conn{private: private}, path, params) do
    case private do
      %{phoenix_router_url: url} when is_binary(url) -> concat_url(url, path, params)
      %{phoenix_endpoint: endpoint} -> concat_url(endpoint.url(), path, params)
    end
  end

  defp guarded_unverified_url(%_{endpoint: endpoint}, path, params) do
    concat_url(endpoint.url(), path, params)
  end

  defp guarded_unverified_url(%URI{} = uri, path, params) do
    append_params(URI.to_string(%{uri | path: path}), params)
  end

  defp guarded_unverified_url(endpoint, path, params) when is_atom(endpoint) do
    concat_url(endpoint.url(), path, params)
  end

  defp guarded_unverified_url(other, path, _params) do
    raise ArgumentError,
          "expected a %Plug.Conn{}, a %Phoenix.Socket{}, a %URI{}, a struct with an :endpoint key, " <>
            "or a Phoenix.Endpoint when building url at #{path}, got: #{inspect(other)}"
  end

  defp concat_url(url, path) when is_binary(path), do: url <> path

  defp concat_url(url, path, params) when is_binary(path) do
    append_params(url <> path, params)
  end

  @doc """
  Generates path to a static asset given its file path.

  See `c:Phoenix.Endpoint.static_path/1` for more information.

  ## Examples

      iex> static_path(conn, "/assets/js/app.js")
      "/assets/js/app-813dfe33b5c7f8388bccaaa38eec8382.js"

      iex> static_path(socket, "assets/js/app.js")
      "/assets/js/app-813dfe33b5c7f8388bccaaa38eec8382.js"

      iex> static_path(AppWeb.Endpoint, "assets/js/app.js")
      "/assets/js/app-813dfe33b5c7f8388bccaaa38eec8382.js"

      iex> static_path(%URI{path: "/subresource"}, "/assets/js/app.js")
      "/subresource/assets/js/app-813dfe33b5c7f8388bccaaa38eec8382.js"
  """
  def static_path(conn_or_socket_or_endpoint_or_uri, path)

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

  ## Examples

      iex> unverified_path(conn, AppWeb.Router, "/posts")
      "/posts"

      iex> unverified_path(conn, AppWeb.Router, "/posts", page: 1)
      "/posts?page=1"
  """
  def unverified_path(conn_or_socket_or_endpoint_or_uri, router, path, params \\ %{})

  def unverified_path(%Plug.Conn{} = conn, router, path, params) do
    conn
    |> build_own_forward_path(router, path)
    |> Kernel.||(build_conn_forward_path(conn, router, path))
    |> Kernel.||(path_with_script(path, conn.script_name))
    |> append_params(params)
  end

  def unverified_path(%URI{} = uri, _router, path, params) do
    append_params((uri.path || "") <> path, params)
  end

  def unverified_path(%_{endpoint: endpoint}, router, path, params) do
    unverified_path(endpoint, router, path, params)
  end

  def unverified_path(endpoint, _router, path, params) when is_atom(endpoint) do
    append_params(endpoint.path(path), params)
  end

  def unverified_path(other, router, path, _params) do
    raise ArgumentError,
          "expected a %Plug.Conn{}, a %Phoenix.Socket{}, a %URI{}, a struct with an :endpoint key, " <>
            "or a Phoenix.Endpoint when building path for #{inspect(router)} at #{path}, got: #{inspect(other)}"
  end

  defp append_params(path, params) when params == %{} or params == [], do: path

  defp append_params(path, params) when is_map(params) or is_list(params) do
    path <> "?" <> __encode_query__(params)
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

  # Segments must always start with /
  defp verify_segment(["/" <> _ | _] = segments, route), do: verify_segment(segments, route, [])

  defp verify_segment(_, route) do
    raise ArgumentError, "paths must begin with /, got: #{Macro.to_string(route)}"
  end

  # separator followed by dynamic
  defp verify_segment(["/" | rest], route, acc), do: verify_segment(rest, route, ["/" | acc])

  # we've found a static segment, return to caller with rewritten query if found
  defp verify_segment(["/" <> _ = segment | rest], route, acc) do
    case {String.split(segment, "?"), rest} do
      {[segment], _} ->
        verify_segment(rest, route, [URI.encode(segment) | acc])

      {[segment, static_query], dynamic_query} ->
        {Enum.reverse([URI.encode(segment) | acc]),
         verify_query(dynamic_query, route, [static_query])}
    end
  end

  # we reached the static query string, return to caller
  defp verify_segment(["?" <> query], _route, acc) do
    {Enum.reverse(acc), [query]}
  end

  # we reached the dynamic query string, return to call with rewritten query
  defp verify_segment(["?" <> static_query_segment | rest], route, acc) do
    {Enum.reverse(acc), verify_query(rest, route, [static_query_segment])}
  end

  defp verify_segment([segment | _], route, _acc) when is_binary(segment) do
    raise ArgumentError,
          "path segments after interpolation must begin with /, got: #{inspect(segment)} in #{Macro.to_string(route)}"
  end

  defp verify_segment(
         [
           {:"::", m1, [{{:., m2, [Kernel, :to_string]}, m3, [dynamic]}, {:binary, _, _} = bin]}
           | rest
         ],
         route,
         [prev | _] = acc
       )
       when is_binary(prev) do
    rewrite = {:"::", m1, [{{:., m2, [__MODULE__, :__encode_segment__]}, m3, [dynamic]}, bin]}
    verify_segment(rest, route, [rewrite | acc])
  end

  defp verify_segment([_ | _], route, _acc) do
    raise ArgumentError,
          "a dynamic ~p interpolation must follow a static segment, got: #{Macro.to_string(route)}"
  end

  # we've reached the end of the path without finding query, return to caller
  defp verify_segment([], _route, acc), do: {Enum.reverse(acc), _query = []}

  defp verify_query(
         [
           {:"::", m1, [{{:., m2, [Kernel, :to_string]}, m3, [arg]}, {:binary, _, _} = bin]}
           | rest
         ],
         route,
         acc
       ) do
    unless is_binary(hd(acc)) do
      raise ArgumentError,
            "interpolated query string params must be separated by &, got: #{Macro.to_string(route)}"
    end

    rewrite = {:"::", m1, [{{:., m2, [__MODULE__, :__encode_query__]}, m3, [arg]}, bin]}
    verify_query(rest, route, [rewrite | acc])
  end

  defp verify_query([], _route, acc), do: Enum.reverse(acc)

  defp verify_query(["=" | rest], route, acc) do
    verify_query(rest, route, ["=" | acc])
  end

  defp verify_query(["&" <> _ = param | rest], route, acc) do
    unless String.contains?(param, "=") do
      raise ArgumentError,
            "expected query string param key to end with = or declare a static key value pair, got: #{inspect(param)}"
    end

    verify_query(rest, route, [param | acc])
  end

  defp verify_query(_other, route, _acc) do
    raise_invalid_query(route)
  end

  defp raise_invalid_query(route) do
    raise ArgumentError,
          "expected query string param to be compile-time map or keyword list, got: #{Macro.to_string(route)}"
  end

  @doc """
  Generates an integrity hash to a static asset given its file path.

  See `c:Phoenix.Endpoint.static_integrity/1` for more information.

  ## Examples

      iex> static_integrity(conn, "/assets/js/app.js")
      "813dfe33b5c7f8388bccaaa38eec8382"

      iex> static_integrity(socket, "/assets/js/app.js")
      "813dfe33b5c7f8388bccaaa38eec8382"

      iex> static_integrity(AppWeb.Endpoint, "/assets/js/app.js")
      "813dfe33b5c7f8388bccaaa38eec8382"
  """
  def static_integrity(conn_or_socket_or_endpoint, path)

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
  def __encode_query__(dict) when is_list(dict) or (is_map(dict) and not is_struct(dict)) do
    case Plug.Conn.Query.encode(dict, &to_param/1) do
      "" -> ""
      query_str -> query_str
    end
  end

  def __encode_query__(val), do: val |> to_param() |> URI.encode_www_form()

  defp to_param(int) when is_integer(int), do: Integer.to_string(int)
  defp to_param(bin) when is_binary(bin), do: bin
  defp to_param(false), do: "false"
  defp to_param(true), do: "true"
  defp to_param(data), do: Phoenix.Param.to_param(data)

  defp build_route(route_ast, sigil_p, env, endpoint_ctx, router) do
    config = Module.get_attribute(env.module, :phoenix_verified_config, [])

    router =
      case Macro.expand(router, env) do
        mod when is_atom(mod) ->
          mod

        other ->
          raise ArgumentError, """
          expected router to be to module, got: #{inspect(other)}

          If your router is not defined at compile-time, use unverified_path/3 instead.
          """
      end

    {static?, meta, test_path, path_ast, static_ast} =
      rewrite_path(route_ast, endpoint_ctx, router, config)

    route = %__MODULE__{
      router: router,
      warn_location: warn_location(meta, env),
      inspected_route: Macro.to_string(sigil_p),
      test_path: test_path
    }

    {route, static?, endpoint_ctx, route_ast, path_ast, static_ast}
  end

  if @after_verify_supported do
    defp warn_location(meta, %{line: line, file: file, function: function, module: module}) do
      column = if column = meta[:column], do: column + 2
      [line: line, function: function, module: module, file: file, column: column]
    end
  else
    defp warn_location(_meta, env) do
      Macro.Env.stacktrace(env)
    end
  end

  defp rewrite_path(route, endpoint, router, config) do
    {:<<>>, meta, segments} = route
    {path_rewrite, query_rewrite} = verify_segment(segments, route)
    path_rewrite = compile_prefixes(config.path_prefixes, meta) ++ path_rewrite

    rewrite_route =
      if query_rewrite == [] do
        {:<<>>, meta, path_rewrite}
      else
        quote generated: true do
          query_str = unquote({:<<>>, meta, query_rewrite})
          path_str = unquote({:<<>>, meta, path_rewrite})

          if query_str == "" do
            path_str
          else
            path_str <> "?" <> query_str
          end
        end
      end

    test_path = Enum.map_join(path_rewrite, &if(is_binary(&1), do: &1, else: "1"))

    static? = static_path?(test_path, config.statics)

    path_ast =
      quote generated: true do
        unquote(__MODULE__).unverified_path(unquote_splicing([endpoint, router, rewrite_route]))
      end

    static_ast =
      quote generated: true do
        unquote(__MODULE__).static_path(unquote_splicing([endpoint, rewrite_route]))
      end

    {static?, meta, test_path, path_ast, static_ast}
  end

  defp compile_prefixes(path_prefixes, meta) do
    Enum.flat_map(path_prefixes, fn
      {module, fun, args} when is_atom(module) and is_atom(fun) and is_list(args) ->
        [
          "/",
          {:"::", meta,
           [{{:., meta, [module, fun]}, meta, Macro.escape(args)}, {:binary, meta, nil}]}
        ]

      other ->
        raise ArgumentError,
              ":path_prefixes option in VerifiedRoutes must be a {mod, fun, args} and return a string, got: #{inspect(other)}"
    end)
  end

  defp attr!(%{function: nil}, _) do
    raise "Phoenix.VerifiedRoutes can only be used inside functions, please move your usage of ~p to functions"
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
