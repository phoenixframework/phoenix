defmodule Phoenix.Router.Mapper do
  alias Phoenix.Router.Path
  alias Phoenix.Controller.Action
  alias Phoenix.Controller.Connection
  alias Phoenix.Router.ResourcesContext
  alias Phoenix.Router.ScopeContext
  alias Phoenix.Router.Errors
  alias Phoenix.Router.Mapper
  alias Phoenix.Router.RouteHelper

  @default_param_key "id"
  @actions [:index, :edit, :new, :show, :create, :update, :destroy]
  @http_methods [:get, :post, :put, :patch, :delete, :options, :connect, :trace,
                 :head]

  @moduledoc """
  Adds Macros for Route match definitions. All routes are
  compiled to pattern matched def match() definitions for fast
  and efficient lookup by the VM.

  ## Examples

      defmodule Router do
        use Phoenix.Router

        get "pages/:page", PageController, :show, as: :page
        resources "users", UserController
      end

      # Compiles to

      get "pages/:page", PageController, :show, as: :page

      -> defmatch({:get, "pages/:page", PageController, :show, [as: :page]})
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

        resources "pages", PageController, only: [:show]
        resources "users", UserController, except: [:destroy]
      end

  ## Generated Routes

      pages_path  GET    /pages/:id       Elixir.PageController.show/2
      users_path  GET    /users           Elixir.UserController.index/2
      users_path  GET    /users/:id/edit  Elixir.UserController.edit/2
      users_path  GET    /users/new       Elixir.UserController.new/2
      users_path  GET    /users/:id       Elixir.UserController.show/2
      users_path  POST   /users           Elixir.UserController.create/2
                  PUT    /users/:id       Elixir.UserController.update/2
                  PATCH  /users/:id       Elixir.UserController.update/2

  """

  defmacro __using__(_options) do
    quote do
      Module.register_attribute __MODULE__, :routes, accumulate: true,
                                                     persist: false
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    routes      = env.module |> Module.get_attribute(:routes) |> Enum.reverse
    mathces_ast = for route <- routes, do: defmatch(route)
    helpers_ast = RouteHelper.defhelpers(routes, env.module)

    quote do
      def __routes__, do: Enum.reverse(@routes)
      unquote(mathces_ast)
      def match(conn, method, path), do: Connection.assign_status(conn, 404)
      unquote(helpers_ast)
      defmodule Helpers, do: unquote(helpers_ast)
    end
  end

  defp defmatch({http_method, path, controller, action, _options}) do
    path_args = Path.matched_arg_list_with_ast_bindings(path)
    params_list_with_bindings = Path.params_with_ast_bindings(path)

    quote do
      def unquote(:match)(conn, unquote(http_method), unquote(path_args)) do
        Action.perform(conn,
          unquote(controller),
          unquote(action),
          unquote(params_list_with_bindings)
        )
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
      current_path = ResourcesContext.current_path(path, __MODULE__)
      {scoped_path, scoped_ctrl, scoped_helper} = ScopeContext.current_scope(
        current_path,
        controller,
        options[:as],
        __MODULE__
      )
      opts = Dict.merge(options, as: scoped_helper)
      @routes {verb, scoped_path, scoped_ctrl, action, opts}
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
      context = %{path: path, name: name, param: param}

      Enum.each actions, fn action ->
        current_alias = ResourcesContext.current_alias(name, __MODULE__)
        opts = [as: current_alias]
        case action do
          :index   -> get    "#{path}",                ctrl, :index, opts
          :show    -> get    "#{path}/:#{param}",      ctrl, :show, opts
          :new     -> get    "#{path}/new",            ctrl, :new, opts
          :edit    -> get    "#{path}/:#{param}/edit", ctrl, :edit, opts
          :create  -> post   "#{path}",                ctrl, :create, opts
          :destroy -> delete "#{path}/:#{param}",      ctrl, :destroy, opts
          :update  ->
            put   "#{path}/:id", ctrl, :update, opts
            patch "#{path}/:id", ctrl, :update, Dict.drop(opts, [:as])
        end
      end

      ResourcesContext.push(context, __MODULE__)
      unquote(nested_context)
      ResourcesContext.pop(__MODULE__)
    end
  end

  defmacro scope(params, do: nested_context) do
    path             = Keyword.get(params, :path)
    controller_alias = Keyword.get(params, :alias)
    helper           = Keyword.get(params, :helper)

    quote unquote: true, bind_quoted: [path: path,
                                       controller_alias: controller_alias,
                                       helper: helper] do
      Errors.ensure_valid_path!(path)
      ScopeContext.push({path, controller_alias, helper}, __MODULE__)
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

      iex> Mapper.resource_name_from_controller(UserController)
      "user"

  """
  def resource_name(controller) do
    Phoenix.Naming.module_name(controller)
    |> String.split(".")
    |> List.last
    |> String.replace("Controller", "")
    |> Phoenix.Naming.underscore
  end
end
