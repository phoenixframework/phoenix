defmodule Phoenix.Template do
  alias Phoenix.Config

  defmodule UndefinedError do
    defexception [:message]
    def exception(opts) do
      %UndefinedError{message: opts[:message]}
    end
  end

  @doc """
  Converts the template file path into a function name

    * path - The String Path to the template file
    * template_root - The String Path of the template root diretory

  ## Examples

      iex> Template.func_name_from_path(
        "lib/templates/admin/users/show.html.eex",
        "lib/templates")
      "admin/users/show.html"

  """
  def func_name_from_path(path, template_root) do
    path
    |> String.replace(template_root, "")
    |> String.lstrip(?/)
    |> String.replace(Path.extname(path), "")
  end

  @doc """
  Returns List of template EEx template file paths
  """
  def find_all_from_root(template_root) do
    extensions = engine_extensions |> Enum.join(",")
    Path.wildcard("#{template_root}/**/*.{#{extensions}}")
  end

  @doc """
  Precompiles the String file_path into a `render/2` function defintion, using
  an engine configured for the template file extension
  """
  def precompile(file_path, root_path) do
    name   = func_name_from_path(file_path, root_path)
    ext    = Path.extname(file_path) |> String.lstrip(?.) |> String.to_atom
    engine = Config.get([:template_engines, ext])
    precompiled_template_func = engine.precompile(file_path, name)

    quote do
      def render(unquote(name)), do: render(unquote(name), [])
      def render(unquote(name), assigns) do
        unquote(:"#{name}")(assigns)
      end

      @external_resource unquote(file_path)
      @file unquote(file_path)
      unquote(precompiled_template_func)
    end
  end

  @doc """
  Returns the EEx engine for the provided String extension
  """
  def eex_engine_for_file_ext(".html"), do: Phoenix.Html.Engine
  def eex_engine_for_file_ext(_ext), do: EEx.SmartEngine

  defp engine_extensions do
    Config.get([:template_engines]) |> Dict.keys
  end
end

