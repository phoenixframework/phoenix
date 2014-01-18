defmodule Phoenix.Router.Path do

  def split(path) do
    String.split(path, "/")
  end

  @doc """
  Splits parameterized String path into list of arguments for defmatch route.
  Named params beginning with ":" are injected into the argument list as 
  an AST binding matching the param name.
  
  Examples
    iex> Path.matched_arg_list_with_ast_bindings("users/:user_id/comments/:id")
    ["users", {:user_id, [], Elixir}, "comments", {:id, [], Elixir}]

  Generated as:
      def match(:get, ["users", user_id, "comments", id])

  """
  def matched_arg_list_with_ast_bindings(path) do
    path
    |> split
    |> Enum.map fn part -> 
      case part do
        <<":" <> param_name>> -> {binary_to_atom(param_name), [], Elixir}
        _ -> part
      end
    end
  end

  @doc """
  Returns Keyword List of parameters from URL matched with 
  AST of associationed bindings for inclusion in defmatch route

  Examples
    iex> Path.params_with_bindings("users/:user_id/comments/:id")
    [user_id: {:user_id, [], Elixir}, id: {:id, [], Elixir}]

  """
  def params_with_ast_bindings(path) do
    Enum.zip(param_names(path), matched_param_ast_bindings(path))
  end

  def matched_param_ast_bindings(path) do
    path
    |> matched_arg_list_with_ast_bindings
    |> Enum.filter(&is_tuple(&1))
  end

  @doc """
  Returns List of atoms of contained named parameters in route

  Examples
    iex> Phoenix.Router.Path.param_names("users/:user_id/comments/:id")
    [:user_id, :id]
    iex> Phoenix.Router.Path.param_names("/pages/about")
    []

  """
  def param_names(path) do
    Regex.scan(%r/:\w+/, path)
    |> List.flatten
    |> Enum.map(&String.strip(&1, ?:))
    |> Enum.map(&binary_to_atom(&1))
  end
end
