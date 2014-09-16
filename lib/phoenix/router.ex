defmodule Phoenix.Router do
  @moduledoc """
  Defines the Phoenix router.

  A router is the heart of a Phoenix application. It has three
  main responsibilities:

    * It provides routes and named route conveniences for
      routing requests to controllers

    * It defines a Plug stack responsible for handling all
      upcoming requests

    * It provides a wrapper for starting and stopping a
      web server specific to this router

  We will explore those responsibilities next.

  ## Routing

  The router provides a set of macros for generating routes
  that dispatches to a specific controller and action. Those
  macros are named after HTTP verbs. For example:

      defmodule MyApp.Router do
        use Phoenix.Router

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

  ## Plug stack

  Documentation upcoming.

  ## Web server

  Documentation upcoming.

  """

  alias Phoenix.Config
  alias Phoenix.Controller.Action
  alias Phoenix.Controller.Connection
  alias Phoenix.Plugs
  alias Phoenix.Plugs.Parsers
  alias Phoenix.Project
  alias Phoenix.Router.Adapter
  alias Phoenix.Router.Resource
  alias Phoenix.Router.Scope
  alias Phoenix.Adapters.Cowboy

  @http_methods [:get, :post, :put, :patch, :delete, :options, :connect, :trace, :head]

  @doc false
  defmacro __using__(plug_adapter_options \\ []) do
    quote do
      import Phoenix.Router
      @before_compile unquote(__MODULE__)
      Module.register_attribute __MODULE__, :phoenix_routes, accumulate: true

      # TODO: This should not be adapter specific.
      use Phoenix.Adapters.Cowboy
      use Plug.Builder

      # TODO: Test and document all of those configurations
      if Config.router(__MODULE__, [:static_assets]) do
        mount = Config.router(__MODULE__, [:static_assets_mount])
        plug Plug.Static, at: mount, from: Project.app
      end

      plug Plug.Logger

      if Config.router(__MODULE__, [:parsers]) do
        plug Plug.Parsers, parsers: [:urlencoded, :multipart, Parsers.JSON], accept: ["*/*"]
      end

      if Config.get([:code_reloader, :enabled]) do
        plug Plugs.CodeReloader
      end

      if Config.router(__MODULE__, [:cookies]) do
        key    = Config.router!(__MODULE__, [:session_key])
        secret = Config.router!(__MODULE__, [:session_secret])

        plug Plug.Session, store: :cookie, key: key, secret: secret
        plug Plugs.SessionFetcher
      end

      plug Plug.MethodOverride

      @options unquote(plug_adapter_options)
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    routes = env.module |> Module.get_attribute(:phoenix_routes) |> Enum.reverse
    Phoenix.Router.Helpers.define(env, routes)

    quote do
      # TODO: Test this is actually added at the end.
      unless Plugs.plugged?(@plugs, :dispatch) do
        plug :dispatch
      end

      # TODO: follow match/dispatch pattern from Plug
      def match(conn, method, path) do
        Connection.assign_status(conn, 404)
      end

      def dispatch(conn, []) do
        Phoenix.Router.Adapter.dispatch(conn, __MODULE__)
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
      @phoenix_routes route

      def unquote(:match)(conn, unquote(route.verb), unquote(route.segments)) do
        Action.perform(conn, unquote(route.controller),
                       unquote(route.action), unquote(route.binding))
      end
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
  defmacro scope(params, do: context) do
    quote do
      Scope.push(__MODULE__, unquote(params))
      try do
        unquote(context)
      after
        Scope.pop(__MODULE__)
      end
    end
  end
end
