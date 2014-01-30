defmodule Phoenix.Router.Mapper do
  alias Phoenix.Router.Path
  alias Phoenix.Controller

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
    IO.puts Macro.to_string(routes_ast)

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
    quote do
      @routes {:get, nested_prefix <> unquote(path), unquote_splicing([controller, action, options])}
    end
  end

  defmacro post(path, controller, action, options // []) do
    quote do
      @routes {:post, nested_prefix <> unquote(path), unquote_splicing([controller, action, options])}
    end
  end

  defmacro put(path, controller, action, options // []) do
    quote do
      @routes {:put, nested_prefix <> unquote(path), unquote_splicing([controller, action, options])}
    end
  end

  defmacro patch(path, controller, action, options // []) do
    quote do
      @routes {:patch, nested_prefix <> unquote(path), unquote_splicing([controller, action, options])}
    end
  end

  defmacro delete(path, controller, action, options // []) do
    quote do
      @routes {:delete, nested_prefix <> unquote(path), unquote_splicing([controller, action, options])}
    end
  end

  defmacro resources(prefix, controller, options // []) do
    # nested_route_ast = quote do
    #   unquote(options[:do])
    # end

    expanded_opts = Macro.expand(options, __MODULE__)
    nested_route = case Keyword.fetch(expanded_opts, :do) do
      {:ok, ast} -> ast
      _ ->
    end

    opts = Keyword.delete(expanded_opts, :do)
    quote do
      options = unquote(opts)
      get    unquote("#{prefix}/:id"), unquote_splicing([controller, :show]), options
      get    unquote("#{prefix}/new"), unquote_splicing([controller, :new]), options
      get    unquote("#{prefix}/"), unquote_splicing([controller, :index]), options
      post   unquote("#{prefix}/"), unquote_splicing([controller, :create]), options
      put    unquote("#{prefix}/:id"), unquote_splicing([controller, :update]), options
      patch  unquote("#{prefix}/:id"), unquote_splicing([controller, :update]), options
      delete unquote("#{prefix}/:id"), unquote_splicing([controller, :destroy]), options
      push_context unquote(prefix)
      unquote(nested_route)
      pop_context
    end
  end

  defmacro nested_prefix do
    quote do
      nested_prefix = (get_context |> Enum.join("/")) <> "/"
    end
  end

  defmacro get_context do
    quote do
      (Module.get_attribute __MODULE__, :nested_context) || []
    end
  end

  defmacro push_context(prefix) do
    quote do
      set_context get_context ++ [unquote(prefix)]
    end
  end

  defmacro pop_context do
    quote do
      set_context(case get_context do
        [_last]  -> []
        []       -> []
        contexts -> contexts |> Enum.reverse |> tl |> Enum.reverse
      end)
    end
  end

  defmacro set_context(context) do
    quote do
      Module.put_attribute __MODULE__, :nested_context, unquote(context)
    end
  end
end

