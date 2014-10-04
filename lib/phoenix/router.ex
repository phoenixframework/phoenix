defmodule Phoenix.Router do
  @moduledoc """
  Defines the Phoenix router.

  A router is the heart of a Phoenix application. It has three
  main responsibilities:

    * It provides routes and named route conveniences for
      routing requests to controllers

    * It defines a plug pipelines responsible for handling
      upcoming requests

    * It hosts configuration for the router and related
      entities (like plugs)

    * It provides a wrapper for starting and stopping a
      web server specific to this router

  We will explore those responsibilities next.

  ## Routing

  The router provides a set of macros for generating routes
  that dispatches to a specific controller and action. Those
  macros are named after HTTP verbs. For example:

      defmodule MyApp.Router do
        use Phoenix.Router

        pipe_through :browser

        get "/pages/:page", PageController, :show
      end

  The `get/3` macro above accepts a request of format "/pages/VALUE" and
  dispatches it to the show action in the `PageController`.

  Phoenix's router is extremely efficient, as it relies on Elixir
  pattern matching for matching routes and serving requests.

  ### Helpers

  Phoenix automatically generates a module `Helpers` inside your router
  which contains named helpers to help developers generate and keep
  their routes up to date.

  Helpers are automatically generated based on the controller name.
  For example, the route:

      get "/pages/:page", PageController, :show

  will generate a named helper:

      MyApp.Router.Helpers.page_path(:show, "hello")
      "/pages/hello"

      MyApp.Router.Helpers.page_path(:show, "hello", some: "query")
      "/pages/hello?some=query"

  The named helper can also be customized with the `:as` option. Given
  the route:

      get "/pages/:page", PageController, :show, as: :special_page

  the named helper will be:

      MyApp.Router.Helpers.special_page_path(:show, "hello")
      "/pages/hello"

  ### Scopes and Resources

  The router also supports scoping of routes:

      scope path: "/api/v1", as: :api_v1 do
        get "/pages/:id", PageController, :show
      end

  For example, the route above will match on the path `"/api/v1/pages/:id"
  and the named route will be `api_v1_page_path`, as expected from the
  values given to `scope/2` option.

  Phoenix also provides a `resources/4` macro that allows developers
  to generate "RESTful" routes to a given resource:

      defmodule MyApp.Router do
        use Phoenix.Router

        pipe_through :browser

        resources "/pages", PageController, only: [:show]
        resources "/users", UserController, except: [:destroy]
      end

  Finally, Phoenix ships with a `mix phoenix.router` task that nicely
  formats all routes in a given router. We can use it to verify all
  routes included in the router above:

      $ mix phoenix.router
      page_path  GET    /pages/:id       PageController.show/2
      user_path  GET    /users           UserController.index/2
      user_path  GET    /users/:id/edit  UserController.edit/2
      user_path  GET    /users/new       UserController.new/2
      user_path  GET    /users/:id       UserController.show/2
      user_path  POST   /users           UserController.create/2
                 PUT    /users/:id       UserController.update/2
                 PATCH  /users/:id       UserController.update/2

  One can also pass a router explicitly as argument to the task:

      $ mix phoenix.router MyApp.Router

  Check `scope/2` and `resources/4` for more information.

  ## Pipelines and plugs

  Once a request arrives to the Phoenix router, it performs
  a series of transformations through pipelines until the
  request is dispatched to a desired end-point.

  Such transformations are defined via plugs, as defined
  in the [Plug](http://github.com/elixir-lang/plug) specification.
  Once a pipeline is defined, it can be piped through per scope.

  For example:

      defmodule MyApp.Router do
        use Phoenix.Router

        scope path: "/" do
          pipe_through :browser

          # browser related routes and resources
        end

        scope path: "/api" do
          pipe_through :api

          # api related routes and resources
        end
      end

  By default, Phoenix ships with three pipelines:

    * `:before` - a special pipeline that is always invoked
      before any route matches
    * `:browser` - a pipeline for handling browser requests
    * `:api` - a pipeline for handling api requests

  All pipelines are invoked after a matching route is found,
  with exception of the `:before` pipeline which is dispatched
  before any attempt to match a route.

  ### :before pipeline

  TODO: Describe plugs in the before pipeline.

  ### :browser pipeline

  TODO: Describe plugs in the browser pipeline.

  ### :api pipeline

  TODO: Describe plugs in the api pipeline.

  ### Customizing pipelines

  You can define new pipelines at any moment with the `pipeline/2`
  macro:

      pipeline :secure do
        plug :token_authentication
      end

  And then in a scope (or at root):

      pipe_through [:api, :secure]

  Pipelines are always defined as overridable functions which means
  they can be easily extended. For example, we can extend the api
  pipeline directly and add security:

      pipeline :api do
        plug :super
        plug :token_authentication
      end

  Where `plug :super` will invoke the previously defined pipeline.
  In general though, it is preferred to define new pipelines then
  modify existing ones.

  ## Configuration

  TODO: documentation

  ## Web server

  TODO: documentation.

  """

  alias Phoenix.Config
  alias Phoenix.Plugs
  alias Phoenix.Project
  alias Phoenix.Router.Adapter
  alias Phoenix.Router.Resource
  alias Phoenix.Router.Scope
  alias Phoenix.Adapters.Cowboy

  @http_methods [:get, :post, :put, :patch, :delete, :options, :connect, :trace, :head]

  @doc false
  defmacro __using__(plug_adapter_options \\ []) do
    prelude   = prelude(plug_adapter_options)
    plug      = plug()
    pipelines = pipelines()
    [prelude, plug, pipelines]
  end

  defp prelude(plug_adapter_options) do
    quote do
      @before_compile Phoenix.Router
      Module.register_attribute __MODULE__, :phoenix_routes, accumulate: true

      import Phoenix.Router
      import Plug.Conn

      # Set up initial scope
      @phoenix_pipeline nil
      Phoenix.Router.Scope.init(__MODULE__)

      # TODO: Document what those options are about
      @options unquote(plug_adapter_options)

      # TODO: This should not be adapter specific.
      use Phoenix.Adapters.Cowboy
    end
  end

  defp plug() do
    {conn, pipeline} =
      [:dispatch, :match, :before]
      |> Enum.map(&{&1, [], true})
      |> Plug.Builder.compile()

    quote do
      @behaviour Plug

      def init(opts) do
        opts
      end

      def call(unquote(conn), opts) do
        unquote(conn) =
          Plug.Conn.put_private(unquote(conn), :phoenix_router, __MODULE__)
        unquote(pipeline)
      end

      def match(conn, []) do
        match(conn, conn.method, conn.path_info)
      end

      def dispatch(conn, []) do
        Phoenix.Router.Adapter.dispatch(conn, __MODULE__)
      end

      defoverridable [init: 1, call: 2, match: 2, dispatch: 2]
    end
  end

  # TODO: Test and document all of those configurations
  defp pipelines() do
    quote do
      pipeline :before do
        if Config.router(__MODULE__, [:static_assets]) do
          mount = Config.router(__MODULE__, [:static_assets_mount])
          plug Plug.Static, at: mount, from: Project.app
        end

        plug Plug.Logger

        if Config.router(__MODULE__, [:parsers]) do
          plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], accept: ["*/*"], json_decoder: Poison
        end

        if Config.get([:code_reloader, :enabled]) do
          plug Plugs.CodeReloader
        end

        plug :put_secret_key_base

        if Config.router(__MODULE__, [:cookies]) do
          key = Config.router!(__MODULE__, [:session_key])
          encrypt = Config.router!(__MODULE__, [:encrypt])
          signing = Config.router!(__MODULE__, [:signing_salt])
          encryption = Config.router!(__MODULE__, [:encryption_salt])

          plug Plug.Session, store: :cookie, key: key, encrypt: true,
                             signing_salt: signing, encryption_salt: encryption
        end
      end

      pipeline :browser do
        if Config.router(__MODULE__, [:cookies]) do
          plug :fetch_session
        end
        plug Plug.MethodOverride
      end

      pipeline :api do
        # Empty by default
      end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    routes = env.module |> Module.get_attribute(:phoenix_routes) |> Enum.reverse
    Phoenix.Router.Helpers.define(env, routes)

    quote do
      defp match(conn, _method, _path) do
        Plug.Conn.put_private(conn, :phoenix_route, fn conn ->
          Plug.Conn.put_status(conn, 404)
        end)
      end

      def start do
        options = Adapter.merge(@options, @dispatch_options, __MODULE__, Cowboy)
        Adapter.start(__MODULE__, options)
      end

      def stop do
        options = Adapter.merge(@options, @dispatch_options, __MODULE__, Cowboy)
        Adapter.stop(__MODULE__, options)
      end

      def __routes__ do
        unquote(Macro.escape(routes))
      end

      # TODO: How is this customizable?
      # We can move it to the controller.
      defp put_secret_key_base(conn, _) do
        put_in conn.secret_key_base, Config.router(__MODULE__, [:secret_key_base])
      end
    end
  end

  for verb <- @http_methods do
    method = verb |> to_string |> String.upcase
    @doc """
    Generates a route to handle a #{verb} request to the given path.
    """
    defmacro unquote(verb)(path, controller, action, options \\ []) do
      add_route(unquote(method), path, controller, action, options)
    end
  end

  defp add_route(verb, path, controller, action, options) do
    quote bind_quoted: binding() do
      route = Scope.route(__MODULE__, verb, path, controller, action, options)
      parts = {:%{}, [], route.binding}
      @phoenix_routes route

      defp match(var!(conn), unquote(route.verb), unquote(route.segments)) do
        var!(conn) =
          Plug.Conn.put_private(var!(conn), :phoenix_route, fn conn ->
            conn = update_in(conn.params, &Map.merge(&1, unquote(parts)))
            opts = unquote(route.controller).init(unquote(route.action))
            unquote(route.controller).call(conn, opts)
          end)
        unquote(route.pipe_through)
      end
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

      scope path: "/" do
        pipe_through :api
      end

  Every time `pipe_through/1` is called, the new pipelines
  are appended to the ones previously given.
  """
  defmacro pipeline(plug, do: block) do
    block =
      quote do
        @phoenix_pipeline []
        unquote(block)
      end

    compiler =
      quote bind_quoted: [plug: plug] do
        Scope.pipeline(__MODULE__, plug)
        {conn, body} = Plug.Builder.compile(@phoenix_pipeline)
        def unquote(plug)(unquote(conn), _), do: unquote(body)
        defoverridable [{plug, 2}]
        @phoenix_pipeline nil
      end

    [block, compiler]
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
      Scope.pipe_through(__MODULE__, unquote(pipes))
    end
  end

  @doc """
  Defines "RESTful" endpoints for a resource.

  The given definition:

      resources "/users", UserController

  will include routes to the following actions:

    * `GET /users` => `:index`
    * `GET /users/new` => `:new`
    * `POST /resources` => `:create`
    * `GET /resources/:id` => `:show`
    * `GET /resources/:id/edit` => `:edit`
    * `PUT /resources/:id` => `:update`
    * `PATCH /resources/:id` => `:update`
    * `DELETE /resources/:id` => `:destroy`

  ## Options

  This macro accepts a set of options:

    * `:only` - a list of actions to generate routes for, for example: `[:show, :edit]`
    * `:except` - a list of actions to exclude generated routes from, for example: `[:destroy]`
    * `:param` - the name of the paramter for this resource, defaults to `"id"`
    * `:name` - the prefix for this resource. This is used for the named helper
      and as the prefix for the parameter in nested resources. The default value
      is automatically derived from the controller name, i.e. `UserController` will
      have name `"user"`
    * `:as` - configures the named helper exclusively

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
    quote do
      # TODO: Support :alias as option (which is passed to scope)
      resource = Resource.build(unquote(path), unquote(controller), unquote(options))

      parm = resource.param
      path = resource.path
      ctrl = resource.controller
      opts = [as: resource.as]

      Enum.each resource.actions, fn action ->
        case action do
          :index   -> get    "#{path}",                ctrl, :index, opts
          :show    -> get    "#{path}/:#{parm}",      ctrl, :show, opts
          :new     -> get    "#{path}/new",            ctrl, :new, opts
          :edit    -> get    "#{path}/:#{parm}/edit", ctrl, :edit, opts
          :create  -> post   "#{path}",                ctrl, :create, opts
          :destroy -> delete "#{path}/:#{parm}",      ctrl, :destroy, opts
          :update  ->
            put   "#{path}/:#{parm}", ctrl, :update, opts
            patch "#{path}/:#{parm}", ctrl, :update, as: nil
        end
      end

      scope resource.member do
        unquote(context)
      end
    end
  end

  @doc """
  Defines a scope in which routes can be nested.

  ## Examples

    scope path: "/api/v1", as: :api_v1, alias: API.V1 do
      get "/pages/:id", PageController, :show
    end

  The generated route above will match on the path `"/api/v1/pages/:id"
  and will dispatch to `:show` action in `API.V1.PageController`. A named
  helper `api_v1_page_path` will also be generated.

  ## Options

  The supported options are:

    * `:path` - a string containing the path scope
    * `:as` - a string or atom containing the named helper scope
    * `:alias` - an alias (atom) containing the controller scope

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
  Define a scope with the given path and alias.

  This function is a shortcut for:

      scope path: path, alias: alias do
        ...
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
end
