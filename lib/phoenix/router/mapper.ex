defmodule Phoenix.Router.Mapper do
  alias Phoenix.Router.Params
  alias Phoenix.Router.Path

  @moduledoc """
  get "/", :pages, :home, as: :home

  map :users, only: [:show] do
    map :comments, only: [:get, :post]
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
      def match(conn, _method, _path), do: Phoenix.Controller.not_found(conn)
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
        def unquote(binary_to_atom "#{alias_name}_path")(), do: unquote(path)
        # TODO: use config based domain for URL
        def unquote(binary_to_atom "#{alias_name}_url")(), do: unquote(path)
      end
    end
  end

  defmacro get(path, controller, action, options // []) do
    quote do
      @routes {:get, unquote_splicing([path, controller, action, options])}
    end
  end

  defmacro post(path, controller, action, options // []) do
    quote do
      @routes {:post, unquote_splicing([path, controller, action, options])}
    end
  end

  defmacro put(path, controller, action, options // []) do
    quote do
      @routes {:put, unquote_splicing([path, controller, action, options])}
    end
  end

  defmacro patch(path, controller, action, options // []) do
    quote do
      @routes {:patch, unquote_splicing([path, controller, action, options])}
    end
  end

  defmacro delete(path, controller, action, options // []) do
    quote do
      @routes {:delete, unquote_splicing([path, controller, action, options])}
    end
  end

  defmacro resources(prefix, controller, options // []) do
    quote do
      get    unquote_splicing(["#{prefix}/:id", controller, :show, options])
      get    unquote_splicing(["#{prefix}", controller, :index, options])
      post   unquote_splicing(["#{prefix}", controller, :create, options])
      put    unquote_splicing(["#{prefix}/:id", controller, :update, options])
      patch  unquote_splicing(["#{prefix}/:id", controller, :update, options])
      delete unquote_splicing(["#{prefix}/:id", controller, :destroy, options])
    end
  end
end
