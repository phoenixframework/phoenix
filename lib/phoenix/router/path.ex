defmodule Phoenix.Router.Path do

  @doc """
  Splits the String path into segments by "/" delimiter
  """
  def split(path), do: String.split(path, "/")

  @doc """
  Joins path List to build valid path
  """
  def join([]), do: ""
  def join(split_path), do: Elixir.Path.join(split_path)

  @doc """
  Returns the AST binding of the given variable with var_name

    * var_name - The String or Atom variable name to be bound

  ## Examples

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

  ## Examples

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
    |> unwrap_arg_list(path)
  end
  defp part_to_ast_binding(<<"*" <> splat_name>>, nil), do: nil
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
  defp unwrap_arg_list([], <<"/*" <> splat_name>>), do: var_ast(splat_name)
  defp unwrap_arg_list(args, _path), do: args


  @doc """
  Returns Keyword List of parameters from URL matched with
  AST of associationed bindings for inclusion in defmatch route

  ## Examples

      iex> Path.params_with_ast_bindings("users/:user_id/comments/:id")
      [{"user_id", {:user_id, [], nil}}, {"id", {:id, [], nil}}]

  """
  def params_with_ast_bindings(path) do
    Enum.zip(param_names(path), matched_param_ast_bindings(path))
  end
  defp matched_param_ast_bindings(path) do
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

  ## Examples

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
  Builds String Path replacing named params with keyword list of values,
  unused parameters are used to construct the query string.

  ## Examples

      iex> Path.build("users/:user_id/comments/:id", user_id: 1, id: 123)
      "/users/1/comments/123"

      iex> Path.build("users/:user_id/comments/:id", user_id: 1, id: 123, highlight: "abc")
      "/users/1/comments/123?highlight=abc"

      iex> Path.build("pages/about", [])
      "/pages/about"

  """
  def build(path, []), do: ensure_leading_slash(path)
  def build(path, param_values) do
    param_names = param_names(path)

    path
    |> replace_param_names_with_values(param_names, param_values)
    |> construct_query_string(param_names, param_values)
    |> ensure_leading_slash
  end
  defp replace_param_names_with_values(path, param_names, param_values) do
    Enum.reduce param_names, path, fn param_name, path_acc ->
      value = param_values[String.to_atom(param_name)] |> to_string
      String.replace(path_acc, ~r/[\:\*]{1}#{param_name}/, value)
    end
  end
  defp construct_query_string(path, param_names, param_values) do
    query_params = \
      Enum.filter(param_values, fn {param_name, _} ->
        !Enum.member?(param_names, to_string(param_name))
      end)

    if Enum.empty?(query_params) do
      path
    else
      path <> "?" <> Plug.Conn.Query.encode(query_params)
    end
  end

  @doc """
  Builds a URL based on options passed.

  ## Examples

      iex> Path.build_url("/users", host: "example.com")
      "http://example.com/users"

      iex> Path.build_url("/users", host: "example.com", ssl: true)
      "https://example.com/users"

      iex> Path.build_url("/users", host: "example.com", port: 8080)
      "http://example.com:8080/users"

      iex> Path.build_url("/users", host: "example.com", port: 80)
      "http://example.com/users"

  """
  def build_url(path, opts \\ []) do
    scheme = if opts[:ssl], do: "https", else: "http"
    host = opts[:host]
    proxy = Enum.member?([80, 443], opts[:port])
    port = if proxy, do: nil, else: opts[:port]
    %URI{scheme: scheme, host: host, path: path, port: port} |> to_string
  end

  @doc """
  Adds leading forward slash to string path if missing

  ## Examples

      iex> Path.ensure_leading_slash("users/1")
      "/users/1"

      iex> Path.ensure_leading_slash("/users/2")
      "/users/2"

  """
  def ensure_leading_slash(path = <<"/" <> _rest>>), do: path
  def ensure_leading_slash(path), do: "/" <> path

  @doc """
  Removes leading forward slash from string path if present

  ## Examples

      iex> Path.ensure_no_leading_slash("users/1")
      "users/1"

      iex> Path.ensure_no_leading_slash("/users/2")
      "users/2"

  """
  def ensure_no_leading_slash(<<"/" <> rest>>), do: rest
  def ensure_no_leading_slash(path), do: path
end

