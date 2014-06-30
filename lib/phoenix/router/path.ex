defmodule Phoenix.Router.Path do

  def split(path), do: String.split(path, "/")

  def join([]), do: ""
  def join(split_path), do: Elixir.Path.join(split_path)

  @doc """
  Returns the AST binding of the given variable with var_name

  var_name - The String or Atom variable name to be bound

  # Examples

  iex> Phoenix.Router.Path.var_ast("my_var")
  {:my_var, [], nil}

  iex> Phoenix.Router.Path.var_ast(:my_var)
  {:my_var, [], nil}
  """
  def var_ast(var_name) when is_binary(var_name) do
    var_ast(String.to_atom(var_name))
  end
  def var_ast(var_name) do
    Macro.var(var_name, nil)
  end

  @doc """
  Splits parameterized String path into list of arguments for defmatch route.
  Named params beginning with ":" are injected into the argument list as
  an AST binding matching the param name.

  Examples
    iex> Path.matched_arg_list_with_ast_bindings("users/:user_id/comments/:id")
    ["users", {:user_id, [], nil}, "comments", {:id, [], nil}]

    iex> Path.matched_arg_list_with_ast_bindings("/pages")
    ["pages"]

    iex> Path.matched_arg_list_with_ast_bindings("/")
    []

  Generated as:
      def match(:get, ["users", user_id, "comments", id])

  """
  def matched_arg_list_with_ast_bindings(path) do
    path
    |> ensure_no_leading_slash
    |> split
    |> Enum.chunk(2, 1, [nil])
    |> Enum.map(fn [part, next] -> part_to_ast_binding(part, next) end)
    |> Enum.filter(fn part -> not(part in [nil, ""]) end)
  end
  defp part_to_ast_binding(<<"*" <> _splat_name>>, nil), do: nil
  defp part_to_ast_binding(<<":" <> param_name>>, <<"*" <> splat_name>>) do
    {:|, [], [var_ast(param_name), var_ast(splat_name)]}
  end
  defp part_to_ast_binding(<<":" <> param_name>>, _next) do
    var_ast(param_name)
  end
  defp part_to_ast_binding(part, <<"*" <> splat_name>>) do
    {:|, [], [part, var_ast(splat_name)]}
  end
  defp part_to_ast_binding(part, _next), do: part


  @doc """
  Returns Keyword List of parameters from URL matched with
  AST of associationed bindings for inclusion in defmatch route

  Examples
    iex> Path.params_with_ast_bindings("users/:user_id/comments/:id")
    [{"user_id", {:user_id, [], nil}}, {"id", {:id, [], nil}}]

  """
  def params_with_ast_bindings(path) do
    Enum.zip(param_names(path), matched_param_ast_bindings(path))
  end

  def matched_param_ast_bindings(path) do
    path
    |> split
    |> Enum.map(fn
      <<":" <> param>> -> var_ast(param)
      <<"*" <> param>> -> quote do: Phoenix.Router.Path.join(unquote(var_ast(param)))
      _part ->
    end)
    |> Enum.filter(&is_tuple(&1))
  end

  @doc """
  Returns List of atoms of contained named parameters in route

  Examples
    iex> Phoenix.Router.Path.param_names("users/:user_id/comments/:id")
    ["user_id", "id"]
    iex> Phoenix.Router.Path.param_names("/pages/about")
    []

  """
  def param_names(path) do
    Regex.scan(~r/[\:\*]{1}\w+/, path)
    |> List.flatten
    |> Enum.map(&String.strip(&1, ?:))
    |> Enum.map(&String.strip(&1, ?*))
  end

  @doc """
  Builds String Path replacing named params with keyword list of values

  # Examples
    iex> Path.build("users/:user_id/comments/:id", user_id: 1, id: 123)
    "/users/1/comments/123"

    iex> Path.build("pages/about", [])
    "/pages/about"

  """
  def build(path, []), do: ensure_leading_slash(path)
  def build(path, param_values) do
    path
    |> param_names
    |> replace_param_names_with_values(param_values, path)
    |> ensure_leading_slash
  end
  defp replace_param_names_with_values(param_names, param_values, path) do
    Enum.reduce param_names, path, fn param_name, path_acc ->
      value = param_values[String.to_atom(param_name)] |> to_string
      String.replace(path_acc, ~r/[\:\*]{1}#{param_name}/, value)
    end
  end

  @doc """
  Builds a URL based on options passed.

  # Examples:
    iex> Path.build_url("/users", "example.com", "https")
    "https://example.com/users"

    iex> Path.build_url("/users", "example.com")
    "http://example.com/users"

  """
  def build_url(path, host, scheme \\ "http") do
    %URI{scheme: scheme, host: host, path: path} |> to_string
  end

  @doc """
  Adds leading forward slash to string path if missing

  # Examples
    iex> Path.ensure_leading_slash("users/1")
    "/users/1"

    iex> Path.ensure_leading_slash("/users/2")
    "/users/2"

  """
  def ensure_leading_slash(path = <<"/" <> _rest>>), do: path
  def ensure_leading_slash(path), do: "/" <> path

  @doc """
  Removes leading forward slash from string path if present

  # Examples
    iex> Path.ensure_no_leading_slash("users/1")
    "users/1"

    iex> Path.ensure_no_leading_slash("/users/2")
    "users/2"

  """
  def ensure_no_leading_slash(<<"/" <> rest>>), do: rest
  def ensure_no_leading_slash(path), do: path
end

