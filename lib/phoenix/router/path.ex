defmodule Phoenix.Router.Path do
  alias Phoenix.Config

  @doc """
  Splits the path into segments by "/" delimiter.
  """
  def split(path), do: String.split(path, "/")

  @doc """
  Joins the given paths into a valid path.
  """
  # TODO: Relying on Path is a bad idea as it may do OS specific checks.
  def join([]), do: ""
  def join(list), do: Elixir.Path.join(list)

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

      iex> Path.build_match("users/:user_id/comments/:id")
      {[:user_id, :id],
       ["users", {:user_id, [], nil}, "comments", {:id, [], nil}]}

      iex> Path.build_match("/pages")
      {[], ["pages"]}

      iex> Path.build_match("/")
      {[], []}

  Generated as:

      def match(:get, ["users", user_id, "comments", id])

  """
  def build_match(path) do
    Plug.Router.Utils.build_match(path)
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
  def build(path, named_param_values, param_values) do
    param_names = param_names(path)
    path
    |> replace_param_names_with_values(param_names, named_param_values)
    |> build(param_values)
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
  def build_url(path_string, named_params, params, module) do
    path_string
    |> build(named_params, params)
    |> build_url(ssl:  Config.router(module, [:ssl]),
                 host: Config.router(module, [:host]),
                 port: Config.router(module, [:proxy_port]) ||
                       Config.router(module, [:port]))
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

