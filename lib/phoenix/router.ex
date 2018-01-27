defmodule Phoenix.Router do
  defmodule NoRouteError do
    @moduledoc """
    Exception raised when no route is found.
    """
    defexception plug_status: 404, message: "no route found", conn: nil, router: nil

    def exception(opts) do
      conn   = Keyword.fetch!(opts, :conn)
      router = Keyword.fetch!(opts, :router)
      path   = "/" <> Enum.join(conn.path_info, "/")

      %NoRouteError{message: "no route found for #{conn.method} #{path} (#{inspect router})",
                    conn: conn, router: router}
    end
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

  The `get/3` macro above accepts a request of format `"/pages/VALUE"` and
  dispatches it to the show action in the `PageController`.

  Routes can also match glob-like patterns, routing any path with a common
  base to the same controller. For example:

      get "/dynamic*anything", DynamicController, :show

  Phoenix's router is extremely efficient, as it relies on Elixir
  pattern matching for matching routes and serving requests.

  ## Helpers

  Phoenix automatically generates a module `Helpers` inside your router
  which contains named helpers to help developers generate and keep
  their routes up to date.

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

      MyAppWeb.Router.Helpers.dynamic_path(conn_or_endpoint, :show, ["dynamic", "something"])
      "/dynamic/something"

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

  The route above will dispatch to `MyApp.PageController`. This syntax
  is not only convenient for developers, since we don't have to repeat
  the `MyApp.` prefix on all routes, but it also allows Phoenix to put
  less pressure in the Elixir compiler. If instead we had written:

      get "/pages/:id", MyAppWeb.PageController, :show

  The Elixir compiler would infer that the router depends directly on
  `MyApp.PageController`, which is not true. By using scopes, Phoenix
  can properly hint to the Elixir compiler the controller is not an
  actual dependency of the router. This provides more efficient
  compilation times.

  Scopes allow us to scope on any path or even on the helper name:

      scope "/api/v1", MyAppWeb, as: :api_v1 do
        get "/pages/:id", PageController, :show
      end

  For example, the route above will match on the path `"/api/v1/pages/:id"`
  and the named route will be `api_v1_page_path`, as expected from the
  values given to `scope/2` option.

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
  request is dispatched to a desired end-point.

  Such transformations are defined via plugs, as defined
  in the [Plug](http://github.com/elixir-lang/plug) specification.
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
  """

  alias Phoenix.Router.Resource
  alias Phoenix.Router.Scope
  alias Phoenix.Router.Route
  alias Phoenix.Router.Helpers

  @http_methods [:get, :post, :put, :patch, :delete, :options, :connect, :trace, :head]

  @doc false
  defmacro __using__(_) do
    quote do
      unquote(prelude())
      unquote(defs())
      unquote(match_dispatch())
    end
  end

  defp prelude() do
    quote do
      Module.register_attribute __MODULE__, :phoenix_routes, accumulate: true
      @phoenix_forwards %{}

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
          Enum.each resource.actions, fn
            :show    -> get    path,            ctrl, :show, opts
            :new     -> get    path <> "/new",  ctrl, :new, opts
            :edit    -> get    path <> "/edit", ctrl, :edit, opts
            :create  -> post   path,            ctrl, :create, opts
            :delete  -> delete path,            ctrl, :delete, opts
            :update  ->
              patch path, ctrl, :update, opts
              put   path, ctrl, :update, Keyword.put(opts, :as, nil)
          end
        else
          param = resource.param

          Enum.each resource.actions, fn
            :index   -> get    path,                             ctrl, :index, opts
            :show    -> get    path <> "/:" <> param,            ctrl, :show, opts
            :new     -> get    path <> "/new",                   ctrl, :new, opts
            :edit    -> get    path <> "/:" <> param <> "/edit", ctrl, :edit, opts
            :create  -> post   path,                             ctrl, :create, opts
            :delete  -> delete path <> "/:" <> param,            ctrl, :delete, opts
            :update  ->
              patch path <> "/:" <> param, ctrl, :update, opts
              put   path <> "/:" <> param, ctrl, :update, Keyword.put(opts, :as, nil)
          end
        end
      end
    end
  end

  @doc false
  def __call__({%Plug.Conn{private: %{phoenix_router: router, phoenix_bypass: {router, pipes}}} = conn, _pipeline, _dispatch}) do
    Enum.reduce(pipes, conn, fn pipe, acc -> apply(router, pipe, [acc, []]) end)
  end
  def __call__({%Plug.Conn{private: %{phoenix_bypass: :all}} = conn, _pipeline, _dispatch}) do
    conn
  end
  def __call__({conn, pipeline, dispatch}) do
    case pipeline.(conn) do
      %Plug.Conn{halted: true} = halted_conn ->
        halted_conn
      %Plug.Conn{} = piped_conn ->
        try do
          dispatch.(piped_conn)
        catch
          :error, reason -> Plug.Conn.WrapperError.reraise(piped_conn, :error, reason)
        end
    end
  end

  defp match_dispatch() do
    quote location: :keep do
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
        conn
        |> prepare()
        |> __match_route__(conn.method, Enum.map(conn.path_info, &URI.decode/1), conn.host)
        |> Phoenix.Router.__call__()
      end

      defoverridable [init: 1, call: 2]
    end
  end

  @anno (if :erlang.system_info(:otp_release) >= '19' do
    [generated: true]
  else
    [line: -1]
  end)

  @doc false
  defmacro __before_compile__(env) do
    routes = env.module |> Module.get_attribute(:phoenix_routes) |> Enum.reverse
    routes_with_exprs = Enum.map(routes, &{&1, Route.exprs(&1)})

    Helpers.define(env, routes_with_exprs)
    matches = Enum.map(routes_with_exprs, &build_match/1)

    # @anno is used here to avoid warnings if forwarding to root path
    match_404 =
      quote @anno do
        def __match_route__(conn, _method, _path_info, _host) do
          raise NoRouteError, conn: conn, router: __MODULE__
        end
      end

    quote do
      @doc false
      def __routes__,  do: unquote(Macro.escape(routes))

      @doc false
      def __helpers__, do: __MODULE__.Helpers

      defp prepare(conn) do
        update_in conn.private,
          &(&1 |> Map.put(:phoenix_pipelines, [])
          |> Map.put(:phoenix_router, __MODULE__)
          |> Map.put(__MODULE__, {conn.script_name, @phoenix_forwards}))
      end

      unquote(matches)
      unquote(match_404)
    end
  end

  defp build_match({route, exprs}) do
    {conn_block, pipelines, dispatch} = exprs.route_match

    quote line: route.line do
      @doc false
      def __match_route__(var!(conn), unquote(exprs.verb_match), unquote(exprs.path),
                 unquote(exprs.host)) do

        unquote(conn_block)
        {var!(conn), unquote(pipelines), unquote(dispatch)}
      end
    end
  end

  @doc """
  Generates a route match based on an arbitrary HTTP method.

  Useful for defining routes not included in the builtin macros:

  #{Enum.map_join(@http_methods, ", ", &"`#{&1}`")}

  The catch-all verb, `:*`, may also be used to match all HTTP methods.

  ## Examples

      match(:move, "/events/:id", EventController, :move)

      match(:*, "/any", SomeController, :any)
  """
  defmacro match(verb, path, plug, plug_opts, options \\ []) do
    add_route(:match, verb, path, plug, plug_opts, options)
  end

  for verb <- @http_methods do
    @doc """
    Generates a route to handle a #{verb} request to the given path.
    """
    defmacro unquote(verb)(path, plug, plug_opts, options \\ []) do
      add_route(:match, unquote(verb), path, plug, plug_opts, options)
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
    block =
      quote do
        plug = unquote(plug)
        @phoenix_pipeline []
        unquote(block)
      end

    compiler =
      quote unquote: false do
        Scope.pipeline(__MODULE__, plug)
        {conn, body} = Plug.Builder.compile(__ENV__, @phoenix_pipeline, [])
        def unquote(plug)(unquote(conn), _) do
          try do
            unquote(body)
          catch
            :error, reason ->
              Plug.Conn.WrapperError.reraise(unquote(conn), :error, reason)
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
    quote do
      if pipeline = @phoenix_pipeline do
        @phoenix_pipeline [{unquote(plug), unquote(opts), true}|pipeline]
      else
        raise "cannot define plug at the router level, plug must be defined inside a pipeline"
      end
    end
  end

  @doc """
  Defines a pipeline to send the connection through.

  See `pipeline/2` for more information.
  """
  defmacro pipe_through(pipes) do
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
    * `:as` - configures the named helper exclusively
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
    add_resources path, controller, opts, do: nested_context
  end

  @doc """
  See `resources/4`.
  """
  defmacro resources(path, controller, do: nested_context) do
    add_resources path, controller, [], do: nested_context
  end

  @doc """
  See `resources/4`.
  """
  defmacro resources(path, controller, opts) do
    add_resources path, controller, opts, do: nil
  end

  @doc """
  See `resources/4`.
  """
  defmacro resources(path, controller) do
    add_resources path, controller, [], do: nil
  end

  defp add_resources(path, controller, options, do: context) do
    scope =
      if context do
        quote do
          scope resource.member, do: unquote(context)
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

      scope path: "/api/v1", as: :api_v1, alias: API.V1 do
        get "/pages/:id", PageController, :show
      end

  The generated route above will match on the path `"/api/v1/pages/:id"`
  and will dispatch to `:show` action in `API.V1.PageController`. A named
  helper `api_v1_page_path` will also be generated.

  ## Options

  The supported options are:

    * `:path` - a string containing the path scope
    * `:as` - a string or atom containing the named helper scope
    * `:alias` - an alias (atom) containing the controller scope
    * `:host` - a string containing the host scope, or prefix host scope,
      ie `"foo.bar.com"`, `"foo."`
    * `:private` - a map of private data to merge into the connection when a route matches
    * `:assigns` - a map of data to merge into the connection when a route matches

  """
  defmacro scope(options, do: context) do
    do_scope(options, context)
  end

  @doc """
  Define a scope with the given path.

  This function is a shortcut for:

      scope path: path do
        ...
      end

  ## Examples

      scope "/api/v1", as: :api_v1, alias: API.V1 do
        get "/pages/:id", PageController, :show
      end

  """
  defmacro scope(path, options, do: context) do
    options = quote do
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

      scope "/api/v1", API.V1, as: :api_v1 do
        get "/pages/:id", PageController, :show
      end

  """
  defmacro scope(path, alias, options, do: context) do
    options = quote do
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
  Forwards a request at the given path to a plug.

  All paths that match the forwarded prefix will be sent to
  the forwarded plug. This is useful for sharing a router between
  applications or even breaking a big router into smaller ones.
  The router pipelines will be invoked prior to forwarding the
  connection.

  The forwarded plug will be initialized at compile time.

  Note, however, that we don't advise forwarding to another
  endpoint. The reason is that plugs defined by your app
  and the forwarded endpoint would be invoked twice, which
  may lead to errors.

  ## Examples

      scope "/", MyApp do
        pipe_through [:browser, :admin]

        forward "/admin", SomeLib.AdminDashboard
        forward "/api", ApiRouter
      end

  """
  defmacro forward(path, plug, plug_opts \\ [], router_opts \\ []) do
    router_opts = Keyword.put(router_opts, :as, nil)

    quote unquote: true, bind_quoted: [path: path, plug: plug] do
      path_segments = Route.forward_path_segments(path, plug, @phoenix_forwards)
      @phoenix_forwards Map.put(@phoenix_forwards, plug, path_segments)
      unquote(add_route(:forward, :*, path, plug, plug_opts, router_opts))
    end
  end
end
