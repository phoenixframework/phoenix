defmodule Phoenix.Router.Mapper do
  alias Phoenix.Controller.Action
  alias Phoenix.Controller.Connection
  alias Phoenix.Router.Resource
  alias Phoenix.Router.Scope

  @http_methods [:get, :post, :put, :patch, :delete, :options, :connect, :trace, :head]

  @moduledoc """
  Adds Macros for Route match definitions. All routes are
  compiled to pattern matched def match() definitions for fast
  and efficient lookup by the VM.

  ## Examples

      defmodule Router do
        use Phoenix.Router

        get "/pages/:page", PageController, :show, as: :page
        resources "/users", UserController
      end

      # Compiles to

      get "/pages/:page", PageController, :show, as: :page

      -> defmatch({:get, "/pages/:page", PageController, :show, [as: :page]})
         defroute_aliases({:get, "pages/:page", PageController, :show, [as: :page]})

      --> def(match(conn, :get, ["pages", page])) do
            Action.perform(conn, PageController, :show, page: page)
          end

  The resources macro accepts flags to limit which resources are generated. Passing
  a list of actions through either :only or :except will prevent building all the
  routes

  ## Examples

      defmodule Router do
        use Phoenix.Router

        resources "/pages", PageController, only: [:show]
        resources "/users", UserController, except: [:destroy]
      end

  ## Generated Routes

      page_path  GET    /pages/:id       PageController.show/2
      user_path  GET    /users           UserController.index/2
      user_path  GET    /users/:id/edit  UserController.edit/2
      user_path  GET    /users/new       UserController.new/2
      user_path  GET    /users/:id       UserController.show/2
      user_path  POST   /users           UserController.create/2
                 PUT    /users/:id       UserController.update/2
                 PATCH  /users/:id       UserController.update/2

  """

  defmacro __using__(_options) do
    quote do
      Module.register_attribute __MODULE__, :routes, accumulate: true
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    routes = env.module |> Module.get_attribute(:routes) |> Enum.reverse
    Phoenix.Router.Helpers.define(env, routes)

    quote do
      def __routes__, do: unquote(Macro.escape(routes))
      # TODO: follow match/dispatch pattern from Plug
      def match(conn, method, path), do: Connection.assign_status(conn, 404)
    end
  end

  for verb <- @http_methods do
    method = verb |> to_string |> String.upcase
    @doc """
    Generates a route to handle #{verb} requests.
    """
    defmacro unquote(verb)(path, controller, action, options \\ []) do
      add_route(unquote(method), path, controller, action, options)
    end
  end

  defp add_route(verb, path, controller, action, options) do
    quote bind_quoted: binding() do
      route = Scope.route(__MODULE__, verb, path, controller, action, options)
      @routes route

      def unquote(:match)(conn, unquote(route.verb), unquote(route.segments)) do
        Action.perform(conn, unquote(route.controller),
                       unquote(route.action), unquote(route.binding))
      end
    end
  end

  @doc """
  Defines RESTful endpoints for a resource, for the following ations:
  `[:index, :create, :show, :update, :destroy]`

    * path - The String resource path, ie "users"
    * controller - The Controller module
    * opts - The optional Keyword List of options
      * only - The list of actions to generate routes for, ie: `[:show, :edit]`
      * except - The actions to exclude generated routes for, ie `[:destroy]`
      * param - The optional key for this resource. Default "id"
      * name - The optional prefix for this resource. Default determined
               by Controller name. ie, UserController => "user"

  """
  defmacro resources(path, controller, opts, do: nested_context) do
    add_resources path, controller, opts, do: nested_context
  end
  defmacro resources(path, controller, do: nested_context) do
    add_resources path, controller, [], do: nested_context
  end
  defmacro resources(path, controller, opts) do
    add_resources path, controller, opts, do: nil
  end
  defmacro resources(path, controller) do
    add_resources path, controller, [], do: nil
  end
  defp add_resources(path, controller, options, do: context) do
    quote do
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
