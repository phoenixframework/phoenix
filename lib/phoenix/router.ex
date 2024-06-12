defmodule Phoenix.Router do
  defmodule NoRouteError do
    @moduledoc """
    Exception raised when no route is found.
    """
    defexception plug_status: 404, message: "no route found", conn: nil, router: nil

    def exception(opts) do
      conn = Keyword.fetch!(opts, :conn)
      router = Keyword.fetch!(opts, :router)
      path = "/" <> Enum.join(conn.path_info, "/")

      %NoRouteError{
        message: "no route found for #{conn.method} #{path} (#{inspect(router)})",
        conn: conn,
        router: router
      }
    end
  end

  defmodule MalformedURIError do
    @moduledoc """
    Exception raised when the URI is malformed on matching.
    """
    defexception [:message, plug_status: 400]
  end

  @moduledoc """
  Defines a Phoenix router.

  The router provides a set of macros for generating routes
  that dispatch to specific controllers and actions. Those
  macros are named after HTTP verbs. For example:

      defmodule MyAppWeb.Router do
        use Phoenix.Router

        get "/pages/:page", PageController, :show
      end

  The `get/3` macro above accepts a request to `/pages/hello` and dispatches
  it to `PageController`'s `show` action with `%{"page" => "hello"}` in
  `params`.

  Phoenix's router is extremely efficient, as it relies on Elixir
  pattern matching for matching routes and serving requests.

  ## Routing

  `get/3`, `post/3`, `put/3`, and other macros named after HTTP verbs are used
  to create routes.

  The route:

      get "/pages", PageController, :index

  matches a `GET` request to `/pages` and dispatches it to the `index` action in
  `PageController`.

      get "/pages/:page", PageController, :show

  matches `/pages/hello` and dispatches to the `show` action with
  `%{"page" => "hello"}` in `params`.

      defmodule PageController do
        def show(conn, params) do
          # %{"page" => "hello"} == params
        end
      end

  Partial and multiple segments can be matched. For example:

      get "/api/v:version/pages/:id", PageController, :show

  matches `/api/v1/pages/2` and puts `%{"version" => "1", "id" => "2"}` in
  `params`. Only the trailing part of a segment can be captured.

  Routes are matched from top to bottom. The second route here:

      get "/pages/:page", PageController, :show
      get "/pages/hello", PageController, :hello

  will never match `/pages/hello` because `/pages/:page` matches that first.

  Routes can use glob-like patterns to match trailing segments.

      get "/pages/*page", PageController, :show

  matches `/pages/hello/world` and puts the globbed segments in `params["page"]`.

      GET /pages/hello/world
      %{"page" => ["hello", "world"]} = params

  Globs cannot have prefixes nor suffixes, but can be mixed with variables:

      get "/pages/he:page/*rest", PageController, :show

  matches

      GET /pages/hello
      %{"page" => "llo", "rest" => []} = params

      GET /pages/hey/there/world
      %{"page" => "y", "rest" => ["there" "world"]} = params

  > #### Why the macros? {: .info}
  >
  > Phoenix does its best to keep the usage of macros low. You may have noticed,
  > however, that the `Phoenix.Router` relies heavily on macros. Why is that?
  >
  > We use `get`, `post`, `put`, and `delete` to define your routes. We use macros
  > for two purposes:
  >
  > * They define the routing engine, used on every request, to choose which
  >   controller to dispatch the request to. Thanks to macros, Phoenix compiles
  >   all of your routes to a single case-statement with pattern matching rules,
  >   which is heavily optimized by the Erlang VM
  >
  > * For each route you define, we also define metadata to implement `Phoenix.VerifiedRoutes`.
  >   As we will soon learn, verified routes allows to us to reference any route
  >   as if it is a plain looking string, except it is verified by the compiler
  >   to be valid (making it much harder to ship broken links, forms, mails, etc
  >   to production)
  >
  > In other words, the router relies on macros to build applications that are
  > faster and safer. Also remember that macros in Elixir are compile-time only,
  > which gives plenty of stability after the code is compiled. Phoenix also provides
  > introspection for all defined routes via `mix phx.routes`.

  ## Generating routes

  For generating routes inside your application,  see the `Phoenix.VerifiedRoutes`
  documentation for `~p` based route generation which is the preferred way to
  generate route paths and URLs with compile-time verification.

  Phoenix also supports generating function helpers, which was the default
  mechanism in Phoenix v1.6 and earlier. We will explore it next.

  ### Helpers (deprecated)

  Phoenix generates a module `Helpers` inside your router by default, which contains
  named helpers to help developers generate and keep their routes up to date.
  Helpers can be disabled by passing `helpers: false` to `use Phoenix.Router`.

  Helpers are automatically generated based on the controller name.
  For example, the route:

      get "/pages/:page", PageController, :show

  will generate the following named helper:

      MyAppWeb.Router.Helpers.page_path(conn_or_endpoint, :show, "hello")
      "/pages/hello"

      MyAppWeb.Router.Helpers.page_path(conn_or_endpoint, :show, "hello", some: "query")
      "/pages/hello?some=query"

      MyAppWeb.Router.Helpers.page_url(conn_or_endpoint, :show, "hello")
      "http://example.com/pages/hello"

      MyAppWeb.Router.Helpers.page_url(conn_or_endpoint, :show, "hello", some: "query")
      "http://example.com/pages/hello?some=query"

  If the route contains glob-like patterns, parameters for those have to be given as
  list:

      MyAppWeb.Router.Helpers.page_path(conn_or_endpoint, :show, ["hello", "world"])
      "/pages/hello/world"

  The URL generated in the named URL helpers is based on the configuration for
  `:url`, `:http` and `:https`. However, if for some reason you need to manually
  control the URL generation, the url helpers also allow you to pass in a `URI`
  struct:

      uri = %URI{scheme: "https", host: "other.example.com"}
      MyAppWeb.Router.Helpers.page_url(uri, :show, "hello")
      "https://other.example.com/pages/hello"

  The named helper can also be customized with the `:as` option. Given
  the route:

      get "/pages/:page", PageController, :show, as: :special_page

  the named helper will be:

      MyAppWeb.Router.Helpers.special_page_path(conn, :show, "hello")
      "/pages/hello"

  ## Scopes and Resources

  It is very common in Phoenix applications to namespace all of your
  routes under the application scope:

      scope "/", MyAppWeb do
        get "/pages/:id", PageController, :show
      end

  The route above will dispatch to `MyAppWeb.PageController`. This syntax
  is not only convenient for developers, since we don't have to repeat
  the `MyAppWeb.` prefix on all routes, but it also allows Phoenix to put
  less pressure on the Elixir compiler. If instead we had written:

      get "/pages/:id", MyAppWeb.PageController, :show

  The Elixir compiler would infer that the router depends directly on
  `MyAppWeb.PageController`, which is not true. By using scopes, Phoenix
  can properly hint to the Elixir compiler the controller is not an
  actual dependency of the router. This provides more efficient
  compilation times.

  Scopes allow us to scope on any path or even on the helper name:

      scope "/v1", MyAppWeb, host: "api." do
        get "/pages/:id", PageController, :show
      end

  For example, the route above will match on the path `"/api/v1/pages/1"`
  and the named route will be `api_v1_page_path`, as expected from the
  values given to `scope/2` option.

  Like all paths you can define dynamic segments that will be applied as
  parameters in the controller:

      scope "/api/:version", MyAppWeb do
        get "/pages/:id", PageController, :show
      end

  For example, the route above will match on the path `"/api/v1/pages/1"`
  and in the controller the `params` argument will have a map with the
  key `:version` with the value `"v1"`.

  Phoenix also provides a `resources/4` macro that allows developers
  to generate "RESTful" routes to a given resource:

      defmodule MyAppWeb.Router do
        use Phoenix.Router

        resources "/pages", PageController, only: [:show]
        resources "/users", UserController, except: [:delete]
      end

  Finally, Phoenix ships with a `mix phx.routes` task that nicely
  formats all routes in a given router. We can use it to verify all
  routes included in the router above:

      $ mix phx.routes
      page_path  GET    /pages/:id       PageController.show/2
      user_path  GET    /users           UserController.index/2
      user_path  GET    /users/:id/edit  UserController.edit/2
      user_path  GET    /users/new       UserController.new/2
      user_path  GET    /users/:id       UserController.show/2
      user_path  POST   /users           UserController.create/2
      user_path  PATCH  /users/:id       UserController.update/2
                 PUT    /users/:id       UserController.update/2

  One can also pass a router explicitly as an argument to the task:

      $ mix phx.routes MyAppWeb.Router

  Check `scope/2` and `resources/4` for more information.

  ## Pipelines and plugs

  Once a request arrives at the Phoenix router, it performs
  a series of transformations through pipelines until the
  request is dispatched to a desired route.

  Such transformations are defined via plugs, as defined
  in the [Plug](https://github.com/elixir-lang/plug) specification.
  Once a pipeline is defined, it can be piped through per scope.

  For example:

      defmodule MyAppWeb.Router do
        use Phoenix.Router

        pipeline :browser do
          plug :fetch_session
          plug :accepts, ["html"]
        end

        scope "/" do
          pipe_through :browser

          # browser related routes and resources
        end
      end

  `Phoenix.Router` imports functions from both `Plug.Conn` and `Phoenix.Controller`
  to help define plugs. In the example above, `fetch_session/2`
  comes from `Plug.Conn` while `accepts/2` comes from `Phoenix.Controller`.

  Note that router pipelines are only invoked after a route is found.
  No plug is invoked in case no matches were found.

  ## How to organize my routes?

  In Phoenix, we tend to define several pipelines, that provide specific
  functionality. For example, the `pipeline :browser` above includes plugs
  that are common for all routes that are meant to be accessed by a browser.
  Similarly, if you are also serving `:api` requests, you would have a separate
  `:api` pipeline that validates information specific to your endpoints.

  Perhaps more importantly, it is also very common to define pipelines specific
  to authentication and authorization. For example, you might have a pipeline
  that requires all users are authenticated. Another pipeline may enforce only
  admin users can access certain routes. Since routes are matched top to bottom,
  it is recommended to place the authenticated/authorized routes before the
  less restricted routes to ensure they are matched first.

  Once your pipelines are defined, you reuse the pipelines in the desired
  scopes, grouping your routes around their pipelines. For example, imagine
  you are building a blog. Anyone can read a post, but only authenticated
  users can create them. Your routes could look like this:

      pipeline :browser do
        plug :fetch_session
        plug :accepts, ["html"]
      end

      pipeline :auth do
        plug :ensure_authenticated
      end

      scope "/" do
        pipe_through [:browser, :auth]

        get "/posts/new", PostController, :new
        post "/posts", PostController, :create
      end

      scope "/" do
        pipe_through [:browser]

        get "/posts", PostController, :index
        get "/posts/:id", PostController, :show
      end

  Note in the above how the routes are split across different scopes.
  While the separation can be confusing at first, it has one big upside:
  it is very easy to inspect your routes and see all routes that, for
  example, require authentication and which ones do not. This helps with
  auditing and making sure your routes have the proper scope.

  You can create as few or as many scopes as you want. Because pipelines
  are reusable across scopes, they help encapsulate common functionality
  and you can compose them as necessary on each scope you define.
  """

  # TODO: Deprecate trailing_slash?
  alias Phoenix.Router.{Resource, Scope, Route, Helpers}

  @http_methods [:get, :post, :put, :patch, :delete, :options, :connect, :trace, :head]

  @doc false
  defmacro __using__(opts) do
    quote do
      unquote(prelude(opts))
      unquote(defs())
      unquote(match_dispatch())
    end
  end

  defp prelude(opts) do
    quote do
      Module.register_attribute(__MODULE__, :phoenix_routes, accumulate: true)
      @phoenix_forwards %{}
      # TODO: Require :helpers to be explicit given
      @phoenix_helpers Keyword.get(unquote(opts), :helpers, true)

      import Phoenix.Router

      # TODO v2: No longer automatically import dependencies
      import Plug.Conn
      import Phoenix.Controller

      # Set up initial scope
      @phoenix_pipeline nil
      Phoenix.Router.Scope.init(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  # Because those macros are executed multiple times,
  # we end-up generating a huge scope that drastically
  # affects compilation. We work around it by defining
  # those functions only once and calling it over and
  # over again.
  defp defs() do
    quote unquote: false do
      var!(add_resources, Phoenix.Router) = fn resource ->
        path = resource.path
        ctrl = resource.controller
        opts = resource.route

        if resource.singleton do
          Enum.each(resource.actions, fn
            :show ->
              get path, ctrl, :show, opts

            :new ->
              get path <> "/new", ctrl, :new, opts

            :edit ->
              get path <> "/edit", ctrl, :edit, opts

            :create ->
              post path, ctrl, :create, opts

            :delete ->
              delete path, ctrl, :delete, opts

            :update ->
              patch path, ctrl, :update, opts
              put path, ctrl, :update, Keyword.put(opts, :as, nil)
          end)
        else
          param = resource.param

          Enum.each(resource.actions, fn
            :index ->
              get path, ctrl, :index, opts

            :show ->
              get path <> "/:" <> param, ctrl, :show, opts

            :new ->
              get path <> "/new", ctrl, :new, opts

            :edit ->
              get path <> "/:" <> param <> "/edit", ctrl, :edit, opts

            :create ->
              post path, ctrl, :create, opts

            :delete ->
              delete path <> "/:" <> param, ctrl, :delete, opts

            :update ->
              patch path <> "/:" <> param, ctrl, :update, opts
              put path <> "/:" <> param, ctrl, :update, Keyword.put(opts, :as, nil)
          end)
        end
      end
    end
  end

  @doc false
  def __call__(
        %{private: %{phoenix_router: router, phoenix_bypass: {router, pipes}}} = conn,
        metadata,
        prepare,
        pipeline,
        _
      ) do
    conn = prepare.(conn, metadata)

    case pipes do
      :current -> pipeline.(conn)
      _ -> Enum.reduce(pipes, conn, fn pipe, acc -> apply(router, pipe, [acc, []]) end)
    end
  end

  def __call__(%{private: %{phoenix_bypass: :all}} = conn, metadata, prepare, _, _) do
    prepare.(conn, metadata)
  end

  def __call__(conn, metadata, prepare, pipeline, {plug, opts}) do
    conn = prepare.(conn, metadata)
    start = System.monotonic_time()
    measurements = %{system_time: System.system_time()}
    metadata = %{metadata | conn: conn}
    :telemetry.execute([:phoenix, :router_dispatch, :start], measurements, metadata)

    case pipeline.(conn) do
      %Plug.Conn{halted: true} = halted_conn ->
        measurements = %{duration: System.monotonic_time() - start}
        metadata = %{metadata | conn: halted_conn}
        :telemetry.execute([:phoenix, :router_dispatch, :stop], measurements, metadata)
        halted_conn

      %Plug.Conn{} = piped_conn ->
        try do
          plug.call(piped_conn, plug.init(opts))
        else
          conn ->
            measurements = %{duration: System.monotonic_time() - start}
            metadata = %{metadata | conn: conn}
            :telemetry.execute([:phoenix, :router_dispatch, :stop], measurements, metadata)
            conn
        rescue
          e in Plug.Conn.WrapperError ->
            measurements = %{duration: System.monotonic_time() - start}
            new_metadata = %{conn: conn, kind: :error, reason: e, stacktrace: __STACKTRACE__}
            metadata = Map.merge(metadata, new_metadata)
            :telemetry.execute([:phoenix, :router_dispatch, :exception], measurements, metadata)
            Plug.Conn.WrapperError.reraise(e)
        catch
          kind, reason ->
            measurements = %{duration: System.monotonic_time() - start}
            new_metadata = %{conn: conn, kind: kind, reason: reason, stacktrace: __STACKTRACE__}
            metadata = Map.merge(metadata, new_metadata)
            :telemetry.execute([:phoenix, :router_dispatch, :exception], measurements, metadata)
            Plug.Conn.WrapperError.reraise(piped_conn, kind, reason, __STACKTRACE__)
        end
    end
  end

  defp match_dispatch() do
    quote location: :keep, generated: true do
      @behaviour Plug

      @doc """
      Callback required by Plug that initializes the router
      for serving web requests.
      """
      def init(opts) do
        opts
      end

      @doc """
      Callback invoked by Plug on every request.
      """
      def call(conn, _opts) do
        %{method: method, path_info: path_info, host: host} = conn = prepare(conn)

        # TODO: Remove try/catch on Elixir v1.13 as decode no longer raises
        decoded =
          try do
            Enum.map(path_info, &URI.decode/1)
          rescue
            ArgumentError ->
              raise MalformedURIError, "malformed URI path: #{inspect(conn.request_path)}"
          end

        case __match_route__(decoded, method, host) do
          {metadata, prepare, pipeline, plug_opts} ->
            Phoenix.Router.__call__(conn, metadata, prepare, pipeline, plug_opts)

          :error ->
            raise NoRouteError, conn: conn, router: __MODULE__
        end
      end

      defoverridable init: 1, call: 2
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    routes = env.module |> Module.get_attribute(:phoenix_routes) |> Enum.reverse()
    forwards = env.module |> Module.get_attribute(:phoenix_forwards)
    routes_with_exprs = Enum.map(routes, &{&1, Route.exprs(&1, forwards)})

    helpers =
      if Module.get_attribute(env.module, :phoenix_helpers) do
        Helpers.define(env, routes_with_exprs)
      end

    {matches, {pipelines, _}} =
      Enum.map_reduce(routes_with_exprs, {[], %{}}, &build_match/2)

    routes_per_path =
      routes_with_exprs
      |> Enum.group_by(&elem(&1, 1).path, &elem(&1, 0))

    verifies =
      routes_with_exprs
      |> Enum.map(&elem(&1, 1).path)
      |> Enum.uniq()
      |> Enum.map(&build_verify(&1, routes_per_path))

    verify_catch_all =
      quote generated: true do
        @doc false
        def __verify_route__(_path_info) do
          :error
        end
      end

    match_catch_all =
      quote generated: true do
        @doc false
        def __match_route__(_path_info, _verb, _host) do
          :error
        end
      end

    forwards =
      for {plug, script_name} <- forwards do
        quote do
          def __forward__(unquote(plug)), do: unquote(script_name)
        end
      end

    forward_catch_all =
      quote generated: true do
        @doc false
        def __forward__(_), do: nil
      end

    checks =
      routes
      |> Enum.uniq_by(&{&1.line, &1.plug})
      |> Enum.map(fn %{line: line, plug: plug} ->
        quote line: line, do: _ = &unquote(plug).init/1
      end)

    keys = [:verb, :path, :plug, :plug_opts, :helper, :metadata]
    routes = Enum.map(routes, &Map.take(&1, keys))

    quote do
      @doc false
      def __routes__, do: unquote(Macro.escape(routes))

      @doc false
      def __checks__, do: unquote({:__block__, [], checks})

      @doc false
      def __helpers__, do: unquote(helpers)

      defp prepare(conn) do
        merge_private(conn, [{:phoenix_router, __MODULE__}, {__MODULE__, conn.script_name}])
      end

      unquote(pipelines)
      unquote(verifies)
      unquote(verify_catch_all)
      unquote(matches)
      unquote(match_catch_all)
      unquote(forwards)
      unquote(forward_catch_all)
    end
  end

  defp build_verify(path, routes_per_path) do
    routes = Map.get(routes_per_path, path)

    forward_plug =
      Enum.find_value(routes, fn
        %{kind: :forward, plug: plug} -> plug
        _ -> nil
      end)

    warn_on_verify? = Enum.all?(routes, & &1.warn_on_verify?)

    quote generated: true do
      def __verify_route__(unquote(path)) do
        {unquote(forward_plug), unquote(warn_on_verify?)}
      end
    end
  end

  defp build_match({route, expr}, {acc_pipes, known_pipes}) do
    {pipe_name, acc_pipes, known_pipes} = build_match_pipes(route, acc_pipes, known_pipes)

    %{
      prepare: prepare,
      dispatch: dispatch,
      verb_match: verb_match,
      path_params: path_params,
      hosts: hosts,
      path: path
    } = expr

    clauses =
      for host <- hosts do
        quote line: route.line do
          def __match_route__(unquote(path), unquote(verb_match), unquote(host)) do
            {unquote(build_metadata(route, path_params)),
             fn var!(conn, :conn), %{path_params: var!(path_params, :conn)} ->
               unquote(prepare)
             end, &(unquote(Macro.var(pipe_name, __MODULE__)) / 1), unquote(dispatch)}
          end
        end
      end

    {clauses, {acc_pipes, known_pipes}}
  end

  defp build_match_pipes(route, acc_pipes, known_pipes) do
    %{pipe_through: pipe_through} = route

    case known_pipes do
      %{^pipe_through => name} ->
        {name, acc_pipes, known_pipes}

      %{} ->
        name = :"__pipe_through#{map_size(known_pipes)}__"
        acc_pipes = [build_pipes(name, pipe_through) | acc_pipes]
        known_pipes = Map.put(known_pipes, pipe_through, name)
        {name, acc_pipes, known_pipes}
    end
  end

  defp build_metadata(route, path_params) do
    %{
      path: path,
      plug: plug,
      plug_opts: plug_opts,
      pipe_through: pipe_through,
      metadata: metadata
    } = route

    pairs = [
      conn: nil,
      route: path,
      plug: plug,
      plug_opts: Macro.escape(plug_opts),
      path_params: path_params,
      pipe_through: pipe_through
    ]

    {:%{}, [], pairs ++ Macro.escape(Map.to_list(metadata))}
  end

  defp build_pipes(name, []) do
    quote do
      defp unquote(name)(conn), do: conn
    end
  end

  defp build_pipes(name, pipe_through) do
    plugs = pipe_through |> Enum.reverse() |> Enum.map(&{&1, [], true})
    opts = [init_mode: Phoenix.plug_init_mode(), log_on_halt: :debug]
    {conn, body} = Plug.Builder.compile(__ENV__, plugs, opts)

    quote do
      defp unquote(name)(unquote(conn)), do: unquote(body)
    end
  end

  @doc """
  Generates a route match based on an arbitrary HTTP method.

  Useful for defining routes not included in the built-in macros.

  The catch-all verb, `:*`, may also be used to match all HTTP methods.

  ## Options

    * `:as` - configures the named helper. If `nil`, does not generate
      a helper. Has no effect when using verified routes exclusively
    * `:alias` - configure if the scope alias should be applied to the route.
      Defaults to true, disables scoping if false.
    * `:log` - the level to log the route dispatching under, may be set to false. Defaults to
      `:debug`. Route dispatching contains information about how the route is handled (which controller
      action is called, what parameters are available and which pipelines are used) and is separate from
      the plug level logging. To alter the plug log level, please see
      https://hexdocs.pm/phoenix/Phoenix.Logger.html#module-dynamic-log-level.
    * `:private` - a map of private data to merge into the connection
      when a route matches
    * `:assigns` - a map of data to merge into the connection when a route matches
    * `:metadata` - a map of metadata used by the telemetry events and returned by
      `route_info/4`
    * `:warn_on_verify` - the boolean for whether matches to this route trigger
      an unmatched route warning for `Phoenix.VerifiedRoutes`. It is useful to ignore
      an otherwise catch-all route definition from being matched when verifying routes.
      Defaults `false`.

  ## Examples

      match(:move, "/events/:id", EventController, :move)

      match(:*, "/any", SomeController, :any)

  """
  defmacro match(verb, path, plug, plug_opts, options \\ []) do
    add_route(:match, verb, path, expand_alias(plug, __CALLER__), plug_opts, options)
  end

  for verb <- @http_methods do
    @doc """
    Generates a route to handle a #{verb} request to the given path.

        #{verb}("/events/:id", EventController, :action)

    See `match/5` for options.
    """
    defmacro unquote(verb)(path, plug, plug_opts, options \\ []) do
      add_route(:match, unquote(verb), path, expand_alias(plug, __CALLER__), plug_opts, options)
    end
  end

  defp add_route(kind, verb, path, plug, plug_opts, options) do
    quote do
      @phoenix_routes Scope.route(
                        __ENV__.line,
                        __ENV__.module,
                        unquote(kind),
                        unquote(verb),
                        unquote(path),
                        unquote(plug),
                        unquote(plug_opts),
                        unquote(options)
                      )
    end
  end

  @doc """
  Defines a plug pipeline.

  Pipelines are defined at the router root and can be used
  from any scope.

  ## Examples

      pipeline :api do
        plug :token_authentication
        plug :dispatch
      end

  A scope may then use this pipeline as:

      scope "/" do
        pipe_through :api
      end

  Every time `pipe_through/1` is called, the new pipelines
  are appended to the ones previously given.
  """
  defmacro pipeline(plug, do: block) do
    with true <- is_atom(plug),
         imports = __CALLER__.macros ++ __CALLER__.functions,
         {mod, _} <- Enum.find(imports, fn {_, imports} -> {plug, 2} in imports end) do
      raise ArgumentError,
            "cannot define pipeline named #{inspect(plug)} " <>
              "because there is an import from #{inspect(mod)} with the same name"
    end

    block =
      quote do
        plug = unquote(plug)
        @phoenix_pipeline []
        unquote(block)
      end

    compiler =
      quote unquote: false do
        Scope.pipeline(__MODULE__, plug)

        {conn, body} =
          Plug.Builder.compile(__ENV__, @phoenix_pipeline, init_mode: Phoenix.plug_init_mode())

        def unquote(plug)(unquote(conn), _) do
          try do
            unquote(body)
          rescue
            e in Plug.Conn.WrapperError ->
              Plug.Conn.WrapperError.reraise(e)
          catch
            :error, reason ->
              Plug.Conn.WrapperError.reraise(unquote(conn), :error, reason, __STACKTRACE__)
          end
        end

        @phoenix_pipeline nil
      end

    quote do
      try do
        unquote(block)
        unquote(compiler)
      after
        :ok
      end
    end
  end

  @doc """
  Defines a plug inside a pipeline.

  See `pipeline/2` for more information.
  """
  defmacro plug(plug, opts \\ []) do
    {plug, opts} = expand_plug_and_opts(plug, opts, __CALLER__)

    quote do
      if pipeline = @phoenix_pipeline do
        @phoenix_pipeline [{unquote(plug), unquote(opts), true} | pipeline]
      else
        raise "cannot define plug at the router level, plug must be defined inside a pipeline"
      end
    end
  end

  defp expand_plug_and_opts(plug, opts, caller) do
    runtime? = Phoenix.plug_init_mode() == :runtime

    plug =
      if runtime? do
        expand_alias(plug, caller)
      else
        plug
      end

    opts =
      if runtime? and Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, caller))
      else
        opts
      end

    {plug, opts}
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:init, 1}})

  defp expand_alias(other, _env), do: other

  @doc """
  Defines a list of plugs (and pipelines) to send the connection through.

  Plugs are specified using the atom name of any imported 2-arity function
  which takes a `%Plug.Conn{}` and options and returns a `%Plug.Conn{}`; for
  example, `:require_authenticated_user`.

  Pipelines are defined in the router; see `pipeline/2` for more information.

      pipe_through [:my_imported_function, :my_pipeline]
  """
  defmacro pipe_through(pipes) do
    pipes =
      if Phoenix.plug_init_mode() == :runtime and Macro.quoted_literal?(pipes) do
        Macro.prewalk(pipes, &expand_alias(&1, __CALLER__))
      else
        pipes
      end

    quote do
      if pipeline = @phoenix_pipeline do
        raise "cannot pipe_through inside a pipeline"
      else
        Scope.pipe_through(__MODULE__, unquote(pipes))
      end
    end
  end

  @doc """
  Defines "RESTful" routes for a resource.

  The given definition:

      resources "/users", UserController

  will include routes to the following actions:

    * `GET /users` => `:index`
    * `GET /users/new` => `:new`
    * `POST /users` => `:create`
    * `GET /users/:id` => `:show`
    * `GET /users/:id/edit` => `:edit`
    * `PATCH /users/:id` => `:update`
    * `PUT /users/:id` => `:update`
    * `DELETE /users/:id` => `:delete`

  ## Options

  This macro accepts a set of options:

    * `:only` - a list of actions to generate routes for, for example: `[:show, :edit]`
    * `:except` - a list of actions to exclude generated routes from, for example: `[:delete]`
    * `:param` - the name of the parameter for this resource, defaults to `"id"`
    * `:name` - the prefix for this resource. This is used for the named helper
      and as the prefix for the parameter in nested resources. The default value
      is automatically derived from the controller name, i.e. `UserController` will
      have name `"user"`
    * `:as` - configures the named helper. If `nil`, does not generate
      a helper. Has no effect when using verified routes exclusively
    * `:singleton` - defines routes for a singleton resource that is looked up by
      the client without referencing an ID. Read below for more information

  ## Singleton resources

  When a resource needs to be looked up without referencing an ID, because
  it contains only a single entry in the given context, the `:singleton`
  option can be used to generate a set of routes that are specific to
  such single resource:

    * `GET /user` => `:show`
    * `GET /user/new` => `:new`
    * `POST /user` => `:create`
    * `GET /user/edit` => `:edit`
    * `PATCH /user` => `:update`
    * `PUT /user` => `:update`
    * `DELETE /user` => `:delete`

  Usage example:

      resources "/account", AccountController, only: [:show], singleton: true

  ## Nested Resources

  This macro also supports passing a nested block of route definitions.
  This is helpful for nesting children resources within their parents to
  generate nested routes.

  The given definition:

      resources "/users", UserController do
        resources "/posts", PostController
      end

  will include the following routes:

      user_post_path  GET     /users/:user_id/posts           PostController :index
      user_post_path  GET     /users/:user_id/posts/:id/edit  PostController :edit
      user_post_path  GET     /users/:user_id/posts/new       PostController :new
      user_post_path  GET     /users/:user_id/posts/:id       PostController :show
      user_post_path  POST    /users/:user_id/posts           PostController :create
      user_post_path  PATCH   /users/:user_id/posts/:id       PostController :update
                      PUT     /users/:user_id/posts/:id       PostController :update
      user_post_path  DELETE  /users/:user_id/posts/:id       PostController :delete

  """
  defmacro resources(path, controller, opts, do: nested_context) do
    add_resources(path, controller, opts, do: nested_context)
  end

  @doc """
  See `resources/4`.
  """
  defmacro resources(path, controller, do: nested_context) do
    add_resources(path, controller, [], do: nested_context)
  end

  defmacro resources(path, controller, opts) do
    add_resources(path, controller, opts, do: nil)
  end

  @doc """
  See `resources/4`.
  """
  defmacro resources(path, controller) do
    add_resources(path, controller, [], do: nil)
  end

  defp add_resources(path, controller, options, do: context) do
    scope =
      if context do
        quote do
          scope(resource.member, do: unquote(context))
        end
      end

    quote do
      resource = Resource.build(unquote(path), unquote(controller), unquote(options))
      var!(add_resources, Phoenix.Router).(resource)
      unquote(scope)
    end
  end

  @doc """
  Defines a scope in which routes can be nested.

  ## Examples

      scope path: "/api/v1", alias: API.V1 do
        get "/pages/:id", PageController, :show
      end

  The generated route above will match on the path `"/api/v1/pages/:id"`
  and will dispatch to `:show` action in `API.V1.PageController`. A named
  helper `api_v1_page_path` will also be generated.

  ## Options

  The supported options are:

    * `:path` - a string containing the path scope.
    * `:as` - a string or atom containing the named helper scope. When set to
      false, it resets the nested helper scopes. Has no effect when using verified
      routes exclusively
    * `:alias` - an alias (atom) containing the controller scope. When set to
      false, it resets all nested aliases.
    * `:host` - a string or list of strings containing the host scope, or prefix host scope,
      ie `"foo.bar.com"`, `"foo."`
    * `:private` - a map of private data to merge into the connection when a route matches
    * `:assigns` - a map of data to merge into the connection when a route matches
    * `:log` - the level to log the route dispatching under, may be set to false. Defaults to
      `:debug`. Route dispatching contains information about how the route is handled (which controller
      action is called, what parameters are available and which pipelines are used) and is separate from
      the plug level logging. To alter the plug log level, please see
      https://hexdocs.pm/phoenix/Phoenix.Logger.html#module-dynamic-log-level.

  """
  defmacro scope(options, do: context) do
    options =
      if Macro.quoted_literal?(options) do
        Macro.prewalk(options, &expand_alias(&1, __CALLER__))
      else
        options
      end

    do_scope(options, context)
  end

  @doc """
  Define a scope with the given path.

  This function is a shortcut for:

      scope path: path do
        ...
      end

  ## Examples

      scope "/v1", host: "api." do
        get "/pages/:id", PageController, :show
      end

  """
  defmacro scope(path, options, do: context) do
    options =
      if Macro.quoted_literal?(options) do
        Macro.prewalk(options, &expand_alias(&1, __CALLER__))
      else
        options
      end

    options =
      quote do
        path = unquote(path)

        case unquote(options) do
          alias when is_atom(alias) -> [path: path, alias: alias]
          options when is_list(options) -> Keyword.put(options, :path, path)
        end
      end

    do_scope(options, context)
  end

  @doc """
  Defines a scope with the given path and alias.

  This function is a shortcut for:

      scope path: path, alias: alias do
        ...
      end

  ## Examples

      scope "/v1", API.V1, host: "api." do
        get "/pages/:id", PageController, :show
      end

  """
  defmacro scope(path, alias, options, do: context) do
    alias = expand_alias(alias, __CALLER__)

    options =
      quote do
        unquote(options)
        |> Keyword.put(:path, unquote(path))
        |> Keyword.put(:alias, unquote(alias))
      end

    do_scope(options, context)
  end

  defp do_scope(options, context) do
    quote do
      Scope.push(__MODULE__, unquote(options))

      try do
        unquote(context)
      after
        Scope.pop(__MODULE__)
      end
    end
  end

  @doc """
  Returns the full alias with the current scope's aliased prefix.

  Useful for applying the same short-hand alias handling to
  other values besides the second argument in route definitions.

  ## Examples

      scope "/", MyPrefix do
        get "/", ProxyPlug, controller: scoped_alias(__MODULE__, MyController)
      end
  """
  @doc type: :reflection
  def scoped_alias(router_module, alias) do
    Scope.expand_alias(router_module, alias)
  end

  @doc """
  Returns the full path with the current scope's path prefix.
  """
  @doc type: :reflection
  def scoped_path(router_module, path) do
    Scope.full_path(router_module, path)
  end

  @doc """
  Forwards a request at the given path to a plug.

  All paths that match the forwarded prefix will be sent to
  the forwarded plug. This is useful for sharing a router between
  applications or even breaking a big router into smaller ones.
  The router pipelines will be invoked prior to forwarding the
  connection.

  However, we don't advise forwarding to another endpoint.
  The reason is that plugs defined by your app and the forwarded
  endpoint would be invoked twice, which may lead to errors.

  ## Examples

      scope "/", MyApp do
        pipe_through [:browser, :admin]

        forward "/admin", SomeLib.AdminDashboard
        forward "/api", ApiRouter
      end

  """
  defmacro forward(path, plug, plug_opts \\ [], router_opts \\ []) do
    {plug, plug_opts} = expand_plug_and_opts(plug, plug_opts, __CALLER__)
    router_opts = Keyword.put(router_opts, :as, nil)

    quote unquote: true, bind_quoted: [path: path, plug: plug] do
      unquote(add_route(:forward, :*, path, plug, plug_opts, router_opts))
    end
  end

  @doc """
  Returns all routes information from the given router.
  """
  def routes(router) do
    router.__routes__()
  end

  @doc """
  Returns the compile-time route info and runtime path params for a request.

  The `path` can be either a string or the `path_info` segments.

  A map of metadata is returned with the following keys:

    * `:log` - the configured log level. For example `:debug`
    * `:path_params` - the map of runtime path params
    * `:pipe_through` - the list of pipelines for the route's scope, for example `[:browser]`
    * `:plug` - the plug to dispatch the route to, for example `AppWeb.PostController`
    * `:plug_opts` - the options to pass when calling the plug, for example: `:index`
    * `:route` - the string route pattern, such as `"/posts/:id"`

  ## Examples

      iex> Phoenix.Router.route_info(AppWeb.Router, "GET", "/posts/123", "myhost")
      %{
        log: :debug,
        path_params: %{"id" => "123"},
        pipe_through: [:browser],
        plug: AppWeb.PostController,
        plug_opts: :show,
        route: "/posts/:id",
      }

      iex> Phoenix.Router.route_info(MyRouter, "GET", "/not-exists", "myhost")
      :error
  """
  @doc type: :reflection
  def route_info(router, method, path, host) when is_binary(path) do
    split_path = for segment <- String.split(path, "/"), segment != "", do: segment
    route_info(router, method, split_path, host)
  end

  def route_info(router, method, split_path, host) when is_list(split_path) do
    with {metadata, _prepare, _pipeline, {_plug, _opts}} <-
           router.__match_route__(split_path, method, host) do
      Map.delete(metadata, :conn)
    end
  end
end
