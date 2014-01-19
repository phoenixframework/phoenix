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
    Enum.reduce routes, nil, fn route, acc ->
      quote do
        defmatch(unquote(route))
        defroute_aliases(unquote(route))
        unquote(acc)
      end
    end
  end

  defmacro defmatch({http_method, path, controller, action, options}) do
    path_args = Path.matched_arg_list_with_ast_bindings(path)
    params_list_with_bindings = Path.params_with_ast_bindings(path)

    ast = quote do
      def unquote(:match)(conn, unquote(http_method), unquote(path_args)) do
        {unquote(controller), unquote(action), unquote(options)}
        conn = conn.params(Dict.merge(conn.params, unquote(params_list_with_bindings)))

        apply(unquote(controller), unquote(action), [conn])
        # {:ok,  conn
        #        |> Plug.Connection.put_resp_content_type("text/plain")
        #        |> Plug.Connection.send(200, "Matched Params: #{inspect conn.params}")
        # }
      end
    end
    # IO.puts Macro.to_string(ast)

    ast
  end

  defmacro defroute_aliases({http_method, path, controller, action, options}) do
    alias_name = options[:as]
    quote do
      if unquote(alias_name) do
        def unquote(binary_to_atom "#{alias_name}_path")(), do: unquote(path)
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

  defmacro resources(prefix, controller, options // []) do
    quote do
      get unquote_splicing(["#{prefix}/:id", controller, :show, options])
      get unquote_splicing(["#{prefix}", controller, :index, options])
      post unquote_splicing(["#{prefix}", controller, :create, options])
    end
  end
end
