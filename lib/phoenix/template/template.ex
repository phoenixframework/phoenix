defmodule Phoenix.Template do

  defmodule UndefinedError do
    defexception [:message]
    def exception(opts) do
      %UndefinedError{message: opts[:message]}
    end
  end

  @doc """
  Converts the template file path into a function name

  path - The String Path to the template file
  template_root - The String Path of the template root diretory

  Examples

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
    Path.wildcard("#{template_root}/**/*.eex")
  end

  @doc """
  Return String template file_path contents, wrapping templates
  in `within` macro to render traditional templates within a layout.

  Examples

  iex> Template.read!("/var/www/templates/pages/home.html.eex")
  <%= within @layout do %>
    <h1>Home Page</h1>
  <% end %>
  """
  def read!(file_path) do
    "<%= within @within do %>#{File.read!(file_path)}<% end %>"
  end
end

