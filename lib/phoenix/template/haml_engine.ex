defmodule Phoenix.Template.HamlEngine do
  alias Phoenix.Template

  @doc """
  Precompiles the String file_path into a function defintion, using Calliope engine

  For example, given "templates/show.html.haml", returns an AST def of the form:

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

  defp read!(file_path) do
    file_path
    |> File.read!
    |> Calliope.Render.precompile
  end
end

