defmodule Phoenix.Router.Mapper do
  alias Phoenix.Controller.Action
  alias Phoenix.Controller.Connection
  alias Phoenix.Router.ScopeContext
  alias Phoenix.Router.Errors
  alias Phoenix.Router.Mapper
  alias Phoenix.Router.Path
  alias Phoenix.Router.Route

  @default_param_key "id"
  @actions [:index, :edit, :new, :show, :create, :update, :destroy]
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
    routes      = env.module |> Module.get_attribute(:routes) |> Enum.reverse
    helpers_ast = defhelpers(routes, env.module)

    quote do
      def __routes__, do: Enum.reverse(@routes)
      # TODO: follow match/dispatch pattern from Plug
      def match(conn, method, path), do: Connection.assign_status(conn, 404)
      unquote(helpers_ast)
      defmodule Helpers, do: unquote(helpers_ast)
    end
  end

  defp defhelpers(routes, module) do
    path_helpers_ast = for route <- routes, do: Route.helper_definition(route)

    quote do
      unquote(path_helpers_ast)
      # TODO: use host/port/schem from Conn
      def url(_conn = %Plug.Conn{}, path), do: url(path)
      def url(path) do
        # TODO: Review this whole config story
        Path.build_url(path, [], [], unquote(module))
      end
    end
  end


  for verb <- @http_methods do
    method = verb |> to_string |> String.upcase
    defmacro unquote(verb)(path, controller, action, options \\ []) do
      add_route(unquote(method), path, controller, action, options)
    end
  end

  defp add_route(verb, path, controller, action, options) do
    quote bind_quoted: [verb: verb,
                        path: path,
                        controller: controller,
                        action: action,
                        options: options] do

      Errors.ensure_valid_path!(path)
      {scoped_path, scoped_ctrl, scoped_helper} = ScopeContext.current_scope(
        path,
        controller,
        options[:as],
        __MODULE__
      )

      route = Route.build(verb, scoped_path, scoped_ctrl, action, scoped_helper)
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
  defp add_resources(path, controller, options, do: nested_context) do
    quote unquote: true, bind_quoted: [options: options,
                                       path: path,
                                       ctrl: controller] do
      Errors.ensure_valid_path!(path)
      actions = Mapper.extract_actions_from_options(options)
      param   = Keyword.get(options, :param, unquote(@default_param_key))
      name    = Keyword.get(options, :name, Mapper.resource_name(ctrl))
      alias   = Keyword.get(options, :alias, Mapper.resource_alias(ctrl))
      as      = Keyword.get(options, :as, name)
      context = [path: Elixir.Path.join(path, ":#{name}_#{param}"), as: as]

      Enum.each actions, fn action ->
        opts = [as: as]
        case action do
          :index   -> get    "#{path}",                ctrl, :index, opts
          :show    -> get    "#{path}/:#{param}",      ctrl, :show, opts
          :new     -> get    "#{path}/new",            ctrl, :new, opts
          :edit    -> get    "#{path}/:#{param}/edit", ctrl, :edit, opts
          :create  -> post   "#{path}",                ctrl, :create, opts
          :destroy -> delete "#{path}/:#{param}",      ctrl, :destroy, opts
          :update  ->
            put   "#{path}/:id", ctrl, :update, opts
            patch "#{path}/:id", ctrl, :update, as: nil
        end
      end

      scope context do
        unquote(nested_context)
      end
    end
  end

  defmacro scope(params, do: nested_context) do
    quote do
      params = unquote(params)
      path   = Keyword.get(params, :path)
      alias  = Keyword.get(params, :alias)
      as     = Keyword.get(params, :as)
      if path, do: Errors.ensure_valid_path!(path)
      ScopeContext.push({path, alias, as}, __MODULE__)
      unquote(nested_context)
      ScopeContext.pop(__MODULE__)
    end
  end

  @doc false
  def extract_actions_from_options(opts) do
    Keyword.get(opts, :only) || (@actions -- Keyword.get(opts, :except, []))
  end

  @doc """
  Converts the controller Module into a String param prefix based on name

  ## Examples

      iex> Mapper.resource_name(UserController)
      "user"

  """
  def resource_name(controller) do
    resource_alias(controller)
    |> Phoenix.Naming.underscore
  end

  def resource_alias(controller) do
    Phoenix.Naming.module_name(controller)
    |> String.split(".")
    |> List.last
    |> String.replace("Controller", "")
  end
end
