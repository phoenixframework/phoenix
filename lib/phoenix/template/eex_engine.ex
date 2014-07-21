defmodule Phoenix.Template.EExEngine do
  alias Phoenix.Template

  @doc """
  Precompiles the String file_path into a function defintion, using EEx Engine

  For example, given "templates/show.html.eex", returns an AST def of the form:

      def render("show.html", assigns \\ [])

  """
  def precompile(file_path, func_name) do
    engine = Template.eex_engine_for_file_ext(Path.extname(func_name))
    content = read!(file_path)

    quote bind_quoted: [func_name: func_name, content: content, engine: engine] do
      EEx.function_from_string(:defp, :"#{func_name}", content, [:assigns],
                               engine: engine)
    end
  end

  @doc """
  Return String template file_path contents, wrapping templates
  in `within` macro to render traditional templates within a layout.

  ## Examples

      iex> Template.read!("/var/www/templates/pages/home.html.eex")
      <%= within @layout do %>
        <h1>Home Page</h1>
      <% end %>

  """
  def read!(file_path) do
    file_path
    |> File.read!
    |> wrap_content(file_path)
  end

  defp wrap_content(content, ~r{layouts\/}),  do: content
  defp wrap_content(content, _file_path) do
    "<%= within @within do %>#{content}<% end %>"
  end
end
