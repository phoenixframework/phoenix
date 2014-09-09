defmodule Phoenix.Router.RouteHelper do
  alias Phoenix.Router.Path

  @moduledoc """
  Builds named route helpers for Routers to regenerate defined route paths
  """

  def defhelpers(routes, module) do
    path_helpers_ast = for route <- routes, do: defhelper(module, route)

    quote do
      unquote(path_helpers_ast)
      # TODO: use host/port/schem from Conn
      def url(_conn = %Plug.Conn{}, path), do: url(path)
      def url(path) do
        Path.build_url(path, [], [], unquote(module))
      end
    end
  end

  @doc ~S"""
  Returns the AST for route helpers to rebuild route path by named function

  ## Examples

      iex> RouteHelper.defhelper("comment", "/comments", :index, MyApp.Router)
      quote do
        def(comment_path(:index, params)) do
          Path.build("/comments", [], params)
        end
      end

      iex> RouteHelper.defhelper("comment", "/comments/:id", :destroy, MyApp.Router)
      quote do
        def(comment_path(:show, id, params)) do
          Path.build("/comments/:id", [id: id], params)
        end
      end

  """
  def defhelper(module, route) do
    defhelper(route.options[:as], route.path, route.action, module)
  end
  defp defhelper(nil, _path, _action, _module), do: nil
  defp defhelper(helper_name, path, action, module) do
    Module.register_attribute(module, :route_helpers, accumulate: true, persist: false)
    helpers    = Module.get_attribute(module, :route_helpers)
    named_args = named_path_args(path)
    named_dict = named_path_dict(path)

    unless Enum.member?(helpers, {helper_name, action}) do
      quote do
        @route_helpers {unquote(helper_name), unquote(action)}
        def unquote(:"#{helper_name}_path")(unquote(action), unquote_splicing(named_args)) do
          unquote(:"#{helper_name}_path")(unquote(action), unquote_splicing(named_args), [])
        end
        def unquote(:"#{helper_name}_path")(unquote(action), unquote_splicing(named_args), params) do
          Path.build(unquote(path), unquote(named_dict), params)
        end
      end
    end
  end

  # Return AST for def [alias]_path arguments based on named params in path
  #
  # Examples
  #
  #    named_path_args("comments/:comment_id/votes/:id")
  #    [comment_id, id]
  #
  defp named_path_args(path) do
    path
    |> Path.param_names
    |> Enum.map(&Path.var_ast(&1))
  end

  # Return AST for def [alias]_path params dict based on named params in path
  #
  # Examples
  #
  #    named_path_dict("comments/:comment_id/votes/:id")
  #    [comment_id: comment_id, id: id]
  #
  defp named_path_dict(path) do
    path
    |> Path.param_names
    |> Enum.map(fn param -> {String.to_atom(param), Path.var_ast(param)} end)
  end
end
