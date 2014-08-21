defmodule Phoenix.Template.EExEngine do
  alias Phoenix.Template
  @behaviour Phoenix.Template.Engine

  @doc """
  Precompiles the String file_path into a function defintion, using EEx Engine

  For example, given "templates/show.html.eex", returns an AST def of the form:

      def render("show.html", assigns \\ [])

  """
  def precompile(file_path, tpl_name) do
    engine = Template.eex_engine_for_file_ext(Path.extname(tpl_name))
    content = read!(file_path)

    quote unquote: true, bind_quoted: [tpl_name: tpl_name, content: content, engine: engine] do
      EEx.function_from_string(:defp, :"#{tpl_name}", content, [:assigns],
                               engine: engine, file: unquote(file_path))

      def render(unquote(tpl_name), assigns) do
        unquote(:"#{tpl_name}")(assigns)
      end
    end
  end

  defp read!(file_path) do
    "<% _ = assigns %>" <> File.read!(file_path)
  end
end
