defmodule Phoenix.Template.EExEngine do
  alias Phoenix.Template
  @behaviour Phoenix.Template.Engine

  @doc """
  Precompiles the String file_path into a function defintion, using EEx Engine

  For example, given "templates/show.html.eex", returns an AST def of the form:

      def render("show.html", assigns \\ [])

  """
  def precompile(file_path, func_name) do
    engine = Template.eex_engine_for_file_ext(Path.extname(func_name))
    content = File.read!(file_path)

    quote bind_quoted: [func_name: func_name, content: content, engine: engine] do
      EEx.function_from_string(:defp, :"#{func_name}", content, [:assigns],
                               engine: engine)
    end
  end
end
