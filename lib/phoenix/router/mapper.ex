defmodule Phoenix.Router.Mapper do
  alias Phoenix.Router.Path
  alias Phoenix.Controller.Action
  alias Phoenix.Router.ResourcesContext
  alias Phoenix.Router.ScopeContext
  alias Phoenix.Router.Errors
  alias Phoenix.Router.Mapper
  alias Phoenix.Router.RouteHelper

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
            Action.perform(conn, PageController, :show, [page: page], Router)
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
      def match(conn, method, path), do: throw({:not_found, conn})
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
      {scoped_path, scoped_controller, scoped_helper} = ScopeContext.current_scope(current_path,
                                                                                   controller,
                                                                                   options[:as],
                                                                                   __MODULE__)
      opts = Dict.merge(options, as: scoped_helper)

      @routes {verb, scoped_path, scoped_controller, action, opts}
    end
  end

  defmacro resources(resource, controller, opts, do: nested_context) do
    add_resources resource, controller, opts, do: nested_context
  end
  defmacro resources(resource, controller, do: nested_context) do
    add_resources resource, controller, [], do: nested_context
  end
  defmacro resources(resource, controller, opts) do
    add_resources resource, controller, opts, do: nil
  end
  defmacro resources(resource, controller) do
    add_resources resource, controller, [], do: nil
  end
  defp add_resources(resource, controller, options, do: nested_context) do
    quote unquote: true, bind_quoted: [options: options,
                                       resource: resource,
                                       controller: controller] do

      actions = Mapper.extract_actions_from_options(options)
      Enum.each actions, fn action ->
        current_alias = ResourcesContext.current_alias(resource, __MODULE__)
        opts = [as: current_alias]
        case action do
          :index   -> get    "/#{resource}",          controller, :index, opts
          :show    -> get    "/#{resource}/:id",      controller, :show, opts
          :new     -> get    "/#{resource}/new",      controller, :new, opts
          :edit    -> get    "/#{resource}/:id/edit", controller, :edit, opts
          :create  -> post   "/#{resource}",          controller, :create, opts
          :destroy -> delete "/#{resource}/:id",      controller, :destroy, opts
          :update  ->
            put   "/#{resource}/:id", controller, :update, []
            patch "/#{resource}/:id", controller, :update, []
        end
      end

      ResourcesContext.push(resource, __MODULE__)
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

      ScopeContext.push({path, controller_alias, helper}, __MODULE__)
      unquote(nested_context)
      ScopeContext.pop(__MODULE__)
    end
  end

  @doc false
  def extract_actions_from_options(opts) do
    Keyword.get(opts, :only) || (@actions -- Keyword.get(opts, :except, []))
  end
end
