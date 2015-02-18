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

  will generate the following named helper:

      MyApp.Router.Helpers.page_path(conn_or_endpoint, :show, "hello")
      "/pages/hello"

      MyApp.Router.Helpers.page_path(conn_or_endpoint, :show, "hello", some: "query")
      "/pages/hello?some=query"

      MyApp.Router.Helpers.page_url(conn_or_endpoint, :show, "hello")
      "http://example.com/pages/hello?some=query"

      MyApp.Router.Helpers.page_url(conn_or_endpoint, :show, "hello", some: "query")
      "http://example.com/pages/hello?some=query"

  The url generated in the named url helpers is based on the configuration for
  `:url`, `:http` and `:https`.

  The named helper can also be customized with the `:as` option. Given
  the route:

      get "/pages/:page", PageController, :show, as: :special_page

  the named helper will be:

      MyApp.Router.Helpers.special_page_path(conn, :show, "hello")
      "/pages/hello"

  ### Scopes and Resources

  The router also supports scoping of routes:

      scope "/api/v1", as: :api_v1 do
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
        resources "/users", UserController, except: [:delete]
      end

  Finally, Phoenix ships with a `mix phoenix.routes` task that nicely
  formats all routes in a given router. We can use it to verify all
  routes included in the router above:

      $ mix phoenix.routes
      page_path  GET    /pages/:id       PageController.show/2
      user_path  GET    /users           UserController.index/2
      user_path  GET    /users/:id/edit  UserController.edit/2
      user_path  GET    /users/new       UserController.new/2
      user_path  GET    /users/:id       UserController.show/2
      user_path  POST   /users           UserController.create/2
      user_path  PATCH  /users/:id       UserController.update/2
                 PUT    /users/:id       UserController.update/2

  One can also pass a router explicitly as an argument to the task:

      $ mix phoenix.routes MyApp.Router

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

        pipeline :browser do
          plug :fetch_session
          plug :accepts, ~w(html json)
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

  ### Channels

  Channels allow you to route pubsub events to channel handlers in your application.
  By default, Phoenix supports both WebSocket and LongPoller transports.
  See the `Phoenix.Channel.Transport` documentation for more information on writing
  your own transports. Chanenls are defined with a `socket` mount, ie:

      defmodule MyApp.Router do
        use Phoenix.Router

        socket "/ws" do
          channel "rooms:*", MyApp.RoomChannel
        end
      end

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
      unquote(plug())
      unquote(control_socket())
    end
  end

  defp prelude() do
    quote do
      Module.register_attribute __MODULE__, :phoenix_routes, accumulate: true
      Module.register_attribute __MODULE__, :phoenix_channels, accumulate: true

      import Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller

      # Set up initial scope
      @phoenix_pipeline nil
      Phoenix.Router.Scope.init(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defp plug() do
    {conn, pipeline} =
      [:dispatch, :match]
      |> Enum.map(&{&1, [], true})
      |> Plug.Builder.compile()

    call =
      quote do
        unquote(conn) =
          update_in unquote(conn).private,
            &(&1 |> Map.put(:phoenix_router, __MODULE__)
                 |> Map.put(:phoenix_pipelines, []))
        unquote(pipeline)
      end

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
      def call(unquote(conn), opts) do
        unquote(call)
      end

      defp match(conn, []) do
        match(conn, conn.method, conn.path_info, conn.host)
      end

      defp dispatch(conn, []) do
        conn.private.phoenix_route.(conn)
      end

      defoverridable [init: 1, call: 2]
    end
  end

  defp control_socket() do
    if Application.get_env(:phoenix, :code_reloader) do
      quote do
        socket "/phoenix" do
          channel "phoenix", Phoenix.Channel.ControlChannel
        end
      end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    routes   = env.module |> Module.get_attribute(:phoenix_routes) |> Enum.reverse
    channels = env.module |> Module.get_attribute(:phoenix_channels) |> Helpers.defchannels

    Helpers.define(env, routes)

    quote do
      @doc false
      def __routes__,  do: unquote(Macro.escape(routes))

      @doc false
      def __helpers__, do: __MODULE__.Helpers

      defp match(conn, _method, _path_info, _host) do
        raise NoRouteError, conn: conn, router: __MODULE__
      end

      unquote(channels)
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

      defp match(var!(conn), unquote(route.verb), unquote(route.path_segments),
                 unquote(route.host_segments)) do
        unquote(Route.maybe_merge(:private, route.private))

        var!(conn) =
          update_in(var!(conn).params, &Map.merge(&1, unquote(parts)))
          |> Plug.Conn.put_private(:phoenix_pipelines, unquote(route.pipe_through))
          |> Plug.Conn.put_private(:phoenix_route, fn conn ->
              opts = unquote(route.controller).init(unquote(route.action))
              unquote(route.controller).call(conn, opts)
             end)

        unquote(route.pipe_segments)
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

      scope "/" do
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
        defp unquote(plug)(unquote(conn), _), do: unquote(body)
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

  @doc """
  Defines "RESTful" routes for a resource that client's lookup without referencing an ID.

  The given definition:

      resource "/account", UserController

  will include routes to the following actions:

    * `GET /account` => `:show`
    * `GET /account/new` => `:new`
    * `POST /account` => `:create`
    * `GET /account/edit` => `:edit`
    * `PATCH /account` => `:update`
    * `PUT /account` => `:update`
    * `DELETE /account` => `:delete`

  ## Options

  This macro accepts the same options as `resources/4`

  """
  defmacro resource(path, controller, opts, do: nested_context) do
    add_resource path, controller, opts, do: nested_context
  end

  @doc """
  See `resource/4`.
  """
  defmacro resource(path, controller, do: nested_context) do
    add_resource path, controller, [], do: nested_context
  end

  @doc """
  See `resource/4`.
  """
  defmacro resource(path, controller, opts) do
    add_resource path, controller, opts, do: nil
  end

  @doc """
  See `resource/4`.
  """
  defmacro resource(path, controller) do
    add_resource path, controller, [], do: nil
  end

  defp add_resources(path, controller, options, do: context) do
    quote do
      resource = Resource.build(unquote(path), unquote(controller), unquote(options))

      parm = resource.param
      path = resource.path
      ctrl = resource.controller
      opts = resource.route

      Enum.each resource.actions, fn action ->
        case action do
          :index   -> get    "#{path}",               ctrl, :index, opts
          :show    -> get    "#{path}/:#{parm}",      ctrl, :show, opts
          :new     -> get    "#{path}/new",           ctrl, :new, opts
          :edit    -> get    "#{path}/:#{parm}/edit", ctrl, :edit, opts
          :create  -> post   "#{path}",               ctrl, :create, opts
          :delete  -> delete "#{path}/:#{parm}",      ctrl, :delete, opts
          :update  ->
            patch "#{path}/:#{parm}", ctrl, :update, opts
            put   "#{path}/:#{parm}", ctrl, :update, Keyword.put(opts, :as, nil)
        end
      end

      scope resource.member do
        unquote(context)
      end
    end
  end

  defp add_resource(path, controller, options, do: context) do
    quote do
      opts     = Keyword.merge(unquote(options), singular: true)
      resource = Resource.build(unquote(path), unquote(controller), opts)

      path = resource.path
      ctrl = resource.controller
      opts = resource.route

      Enum.each resource.actions, fn action ->
        case action do
          :show    -> get    "#{path}",      ctrl, :show, opts
          :new     -> get    "#{path}/new",  ctrl, :new, opts
          :edit    -> get    "#{path}/edit", ctrl, :edit, opts
          :create  -> post   "#{path}",      ctrl, :create, opts
          :delete  -> delete "#{path}",      ctrl, :delete, opts
          :update  ->
            patch "#{path}", ctrl, :update, opts
            put   "#{path}", ctrl, :update, Keyword.put(opts, :as, nil)
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

    scope "/api/v1", as: :api_v1, alias: API.V1 do
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
    * `:host` - a string containing the host scope, or prefix host scope, ie
                `"foo.bar.com"`, `"foo."`
    * `:private` - a map of private data to merge into the connection when a route matches

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
  Defines a scope with the given path and alias.

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

  @doc """
  Defines a socket mount-point for channel definitions.

  By default, the given path is a websocket upgrade endpoint,
  with long-polling fallback. The transports can be configured
  with the socket options or on each individual channel.

  It expects the `mount` path as a string and a keyword list
  of options.

  ## Options

    * `:via` - the optional transport modules to apply to all
      channels in the block, ie: `[Phoenix.Transports.WebSocket]`

    * `:as` - the optional named route helper function, ie `:socket`

    * `:alias` - the optional alias to apply to all channel modules,
      ie: `MyApp`. Alternatively, you can pass an alias as a standalone
      second argument to apply the alias, similar to `scope/2`.

  ## Examples

      socket "/ws" do
        channel "rooms:*", MyApp.RoomChannel
      end

      socket "/ws", MyApp do
        channel "rooms:*", RoomChannel
      end

      socket "/ws", alias: MyApp, as: :socket, via: [Phoenix.Transports.WebSocket] do
        channel "rooms:*", RoomChannel
      end

  """
  defmacro socket(mount, do: chan_block) do
    add_socket(mount, [], chan_block)
  end
  defmacro socket(mount, opts, do: chan_block) when is_list(opts) do
    add_socket(mount, opts, chan_block)
  end
  defmacro socket(mount, chan_alias, do: chan_block) do
    add_socket(mount, [alias: chan_alias], chan_block)
  end
  defmacro socket(mount, chan_alias, opts, do: chan_block) do
    add_socket(mount, Dict.merge(opts, alias: chan_alias), chan_block)
  end
  defp add_socket(mount, opts, chan_block) do
    quote bind_quoted: [mount: mount, opts: opts], unquote: true do
      if Scope.inside_scope?(__MODULE__) do
        raise """
        You are trying to call `socket` within a `scope` definition.
        Please move your socket and channel definitions outside of any scope block.
        """
      end

      @phoenix_socket_mount mount
      @phoenix_transports opts[:via]
      @phoenix_channel_alias opts[:alias]
      get  @phoenix_socket_mount, Phoenix.Transports.WebSocket, :upgrade, Dict.take(opts, [:as])
      post @phoenix_socket_mount, Phoenix.Transports.WebSocket, :upgrade
      get  @phoenix_socket_mount <> "/poll", Phoenix.Transports.LongPoller, :poll
      post @phoenix_socket_mount <> "/poll", Phoenix.Transports.LongPoller, :publish
      unquote(chan_block)
      @phoenix_socket_mount nil
      @phoenix_transports nil
      @phoenix_channel_alias nil
    end
  end

  @doc """
  Defines a channel matching the given topic and transports.

    * `topic_pattern` - The string pattern, ie "rooms:*", "users:*", "system"
    * `module` - The channel module handler, ie `MyApp.RoomChannel`
    * `opts` - The optional list of options, see below

  ## Options

    * `:via` - the transport adapters to accept on this channel.
      Defaults `[Phoenix.Transports.WebSocket, Phoenix.Transports.LongPoller]`

  ## Examples

      socket "/ws" do
        channel "topic1:*", MyChannel
        channel "topic2:*", MyChannel, via: [Phoenix.Transports.WebSocket]
        channel "topic",    MyChannel, via: [Phoenix.Transports.LongPoller]
      end

  ## Topic Patterns

  The `channel` macro accepts topic patterns in two flavors. A splat argument
  can be provided as the last character to indicate a "topic:subtopic" match. If
  a plain string is provied, only that topic will match the channel handler.
  Most use-cases will use the "topic:*" pattern to allow more versatile topic
  scoping.

  See `Phoenix.Channel` for more information
  """
  defmacro channel(topic_pattern, module, opts \\ []) do
    quote bind_quoted: binding do
      unless @phoenix_socket_mount do
        raise """
        You are trying to call `channel` outside of a `socket` block.
        Please move your channel definitions inside a `socket` block.
        """
      end

      @phoenix_channels {topic_pattern,
                         Module.concat(@phoenix_channel_alias, module),
                         Dict.merge([via: @phoenix_transports], opts)}
    end
  end
end
