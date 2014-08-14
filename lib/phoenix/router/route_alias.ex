defmodule Phoenix.Router.RouteAlias do
  alias Phoenix.Router.Path

  @moduledoc """
  Builds named route aliases for Routers to regenerate defined route paths
  """

  @doc ~S"""
  Returns the AST for route aliases to rebuild route path by named function

  ## Examples

      iex> RouteAlias.defalias("comments", "/comments", :index, MyApp.Router)
      quote do
        def(comments_path(:index, params)) do
          Path.build("/comments", [], params)
        end
        def(comments_url(:index, params)) do
          Path.build_url("/comments", [], params, __MODULE__)
        end
      end

      iex> RouteAlias.defaliases("comments", "/comments/:id", :destroy, MyApp.Router)
      quote do
        def(comments_path(:show, id, params)) do
          Path.build("/comments/:id", [id: id], params)
        end
        def(comments_url(:show, id, params)) do
          Path.build_url("/comments/:id", [id: id], params, __MODULE__)
        end
      end

  """
  def defalias(alias_name, path, action, module) do
    Module.register_attribute(module, :route_aliases, accumulate: true, persist: false)
    aliases    = Module.get_attribute(module, :route_aliases)
    named_args = named_path_args(path)
    named_dict = named_path_dict(path)

    unless Enum.member?(aliases, {alias_name, action}) do
      quote do
        @route_aliases {unquote(alias_name), unquote(action)}
        def unquote(:"#{alias_name}_path")(unquote(action), unquote_splicing(named_args)) do
          unquote(:"#{alias_name}_path")(unquote(action), unquote_splicing(named_args), [])
        end
        def unquote(:"#{alias_name}_url")(unquote(action), unquote_splicing(named_args)) do
          unquote(:"#{alias_name}_url")(unquote(action), unquote_splicing(named_args), [])
        end
        def unquote(:"#{alias_name}_path")(unquote(action), unquote_splicing(named_args), params) do
          Path.build(unquote(path), unquote(named_dict), params)
        end
        def unquote(:"#{alias_name}_url")(unquote(action), unquote_splicing(named_args), params) do
          Path.build_url(unquote(path), unquote(named_dict), params, __MODULE__)
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
