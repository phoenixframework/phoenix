defmodule Phoenix.Template.EExEngine do
  @behaviour Phoenix.Template.Engine

  @doc """
  Precompiles the String file_path into a function defintion, using EEx Engine

  For example, given "templates/show.html.eex", returns an AST def of the form:

      def render("show.html", assigns \\ [])

  """
  def compile(file, template) do
    engine = Phoenix.Template.eex_engine_for_file_ext(Path.extname(template))
    opts   = [engine: engine, file: file, line: 1]
    EEx.compile_string(File.read!(file), opts)
  end
end
