defmodule Phoenix.Router.Mapper do
  alias Phoenix.Router.Path
  alias Phoenix.Controller
  alias Phoenix.Router.Context

  @actions [:index, :edit, :show, :new, :create, :update, :destroy]

  @moduledoc """
  Adds Macros for Route match definitions. All routes are
  compiled to patterm matched def match() definitions for fast
  and efficient lookup by the VM.

  # Examples

  defmodule Router do
    use Phoenix.Router, port: 4000

    get "pages/:page", PagesController, :show, as: :page
    resources "users", UsersController
  end

  Compiles to

    get "pages/:page", PagesController, :show, as: :page

    -> defmatch({:get, "pages/:page", PagesController, :show, [as: :page]})
       defroute_aliases({:get, "pages/:page", PagesController, :show, [as: :page]})

    --> def(match(conn, :get, ["pages", page])) do
          conn = conn.params(Dict.merge(conn.params(), [{"page", page}]))
          apply(PagesController, :show, [conn])
        end
  
  The resources macro accepts flags to limit which resources are generated. Passing
  a list of actions through either :only or :except will prevent building all the
  routes

  # Examples

  defmodule Router do
    use Phoenix.Router, port: 4000

    resources "pages", Controllers.Pages, only: [ :show ]
    resources "users", Controllers.Users, except: [ :destroy ]
  end

  Generated Routes

    page      GET   pages/:id      Elixir.Controllers.Pages#show

    users     GET   users          Elixir.Controllers.Users#new
    new_user  GET   users/new      Elixir.Controllers.Users#new
    edit_user GET   users/:id/edit Elixir.Controllers.Users#edit
    user      GET   users/:id      Elixir.Controllers.Users#show

              POST  users          Elixir.Controllers.Users#create
              PUT   users/:id      Elixir.Controllers.Users#update
              PATCH users/:id      Elixir.Controllers.Users#update
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
    routes = Enum.reverse(Module.get_attribute(env.module, :routes))
    routes_ast = Enum.reduce routes, nil, fn route, acc ->
      quote do
        defmatch(unquote(route))
        defroute_aliases(unquote(route))
        unquote(acc)
      end
    end

    quote do
      def __routes__, do: Enum.reverse(@routes)
      unquote(routes_ast)
      def match(conn, method, path), do: Controller.not_found(conn, method, path)
    end
  end

  defmacro defmatch({http_method, path, controller, action, _options}) do
    path_args = Path.matched_arg_list_with_ast_bindings(path)
    params_list_with_bindings = Path.params_with_ast_bindings(path)

    quote do
      def unquote(:match)(conn, unquote(http_method), unquote(path_args)) do
        conn = conn.params(Dict.merge(conn.params, unquote(params_list_with_bindings)))

        apply(unquote(controller), unquote(action), [conn])
      end
    end
  end

  defmacro defroute_aliases({_http_method, path, _controller, _action, options}) do
    alias_name = options[:as]
    if alias_name do
      quote do
        def unquote(binary_to_atom "#{alias_name}_path")(params \\ []) do
          Path.build(unquote(path), params)
        end
        # TODO: use config based domain for URL
        def unquote(binary_to_atom "#{alias_name}_url")(params \\ []) do
          Path.build(unquote(path), params)
        end
      end
    end
  end

  defmacro get(path, controller, action, options \\ []) do
    add_route(:get, path, controller, action, options)
  end

  defmacro post(path, controller, action, options \\ []) do
    add_route(:post, path, controller, action, options)
  end

  defmacro put(path, controller, action, options \\ []) do
    add_route(:put, path, controller, action, options)
  end

  defmacro patch(path, controller, action, options \\ []) do
    add_route(:patch, path, controller, action, options)
  end

  defmacro delete(path, controller, action, options \\ []) do
    add_route(:delete, path, controller, action, options)
  end

  defp add_route(verb, path, controller, action, options) do
    quote bind_quoted: [verb: verb,
                        path: path,
                        controller: controller,
                        action: action,
                        options: options] do

      current_path = Context.current_path(path, __MODULE__)
      @routes {verb, current_path, controller, action, options}
    end
  end

  defmacro resources(resource, controller, options \\ []) do
    nested_route  = Keyword.get(options, :do)
    actions       = extract_actions_from_options(options)
    options       = Keyword.delete(options, :do)

    quote unquote: true, bind_quoted: [actions: actions,
                                       options: options,
                                       resource: resource,
                                       controller: controller] do
      Enum.each actions, fn action ->
        current_alias = Context.current_alias(action, resource, __MODULE__)
        opts = Dict.merge(options, as: current_alias)
        case action do
          :index   -> get    "#{resource}",          controller, :index, opts
          :show    -> get    "#{resource}/:id",      controller, :show, opts
          :new     -> get    "#{resource}/new",      controller, :new, opts
          :edit    -> get    "#{resource}/:id/edit", controller, :edit, opts
          :create  -> post   "#{resource}",          controller, :create, opts
          :destroy -> delete "#{resource}/:id",      controller, :destroy, opts
          :update  ->
            put   "#{resource}/:id", controller, :update, options
            patch "#{resource}/:id", controller, :update, options
        end
      end

      Context.push(resource, __MODULE__)
      unquote(nested_route)
      Context.pop(__MODULE__)
    end
  end

  defp extract_actions_from_options(opts) do
    Keyword.get(opts, :only) || (@actions -- Keyword.get(opts, :except, []))
  end
end

