defmodule Phoenix.Router.Mapper do
  alias Phoenix.Router.Path
  alias Phoenix.Controller

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
      unquote(routes_ast)
      def match(conn, method, path), do: Controller.not_found(conn, method, path)
    end
  end

  defmacro defmatch({http_method, path, controller, action, options}) do
    path_args = Path.matched_arg_list_with_ast_bindings(path)
    params_list_with_bindings = Path.params_with_ast_bindings(path)

    quote do
      def unquote(:match)(conn, unquote(http_method), unquote(path_args)) do
        conn = conn.params(Dict.merge(conn.params, unquote(params_list_with_bindings)))

        apply(unquote(controller), unquote(action), [conn])
      end
    end
  end

  defmacro defroute_aliases({http_method, path, controller, action, options}) do
    alias_name = options[:as]
    quote do
      if unquote(alias_name) do
        def unquote(binary_to_atom "#{alias_name}_path")(params) do
          Path.build(unquote(path), params)
        end
        # TODO: use config based domain for URL
        def unquote(binary_to_atom "#{alias_name}_url")(params) do
          Path.build(unquote(path), params)
        end
      end
    end
  end

  defmacro get(path, controller, action, options // []) do
    add_route(:get, path, controller, action, options)
  end

  defmacro post(path, controller, action, options // []) do
    add_route(:post, path, controller, action, options)
  end

  defmacro put(path, controller, action, options // []) do
    add_route(:put, path, controller, action, options)
  end

  defmacro patch(path, controller, action, options // []) do
    add_route(:patch, path, controller, action, options)
  end

  defmacro delete(path, controller, action, options // []) do
    add_route(:delete, path, controller, action, options)
  end

  defp add_route(verb, path, controller, action, options // []) do
    quote bind_quoted: [verb: verb,
                        path: path,
                        controller: controller,
                        action: action,
                        options: options] do
      @routes {
        verb,
        Phoenix.Router.Context.current_prefix(path, __MODULE__),
        controller,
        action,
        options
      }
    end
  end

  defmacro resources(prefix, controller, options // []) do
    nested_route  = Keyword.get(options, :do)
    actions       = extract_actions_from_options(options)
    options       = Keyword.delete(options, :do)

    quote unquote: true, bind_quoted: [actions: actions,
                                       options: options,
                                       prefix: prefix,
                                       controller: controller] do
      Enum.each actions, fn
        :index   -> get    "#{prefix}",          controller, :index, options
        :show    -> get    "#{prefix}/:id",      controller, :show, options
        :new     -> get    "#{prefix}/new",      controller, :new, options
        :edit    -> get    "#{prefix}/:id/edit", controller, :edit, options
        :create  -> post   "#{prefix}",          controller, :create, options
        :destroy -> delete "#{prefix}/:id",      controller, :destroy, options
        :update  ->
          put   "#{prefix}/:id", controller, :update, options
          patch "#{prefix}/:id", controller, :update, options
      end

      Phoenix.Router.Context.push(prefix, __MODULE__)
      unquote(nested_route)
      Phoenix.Router.Context.pop(__MODULE__)
    end
  end

  defp extract_actions_from_options(opts) do
    Keyword.get(opts, :only) || (@actions -- Keyword.get(opts, :except, []))
  end
end

