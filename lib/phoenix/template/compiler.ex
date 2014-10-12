defmodule Phoenix.Template.Compiler do
  alias Phoenix.Template

  @moduledoc """
  Precompiles EEx templates into view module and provides `render` support

  Uses Mix config `:template_engines` dict to map template extensions to
  Template Engine compilers.

  ## Template Engines

  See the Phoenix.Template.Engine behaviour for custom engines

  ## Examples

      defmodule MyApp.MyView do
        use Phoenix.Template.Compiler, path: Path.join([__DIR__, "templates"])
      end

      iex> MyApp.MyView.render("show.html", message: "Hello!")
      "<h1>Hello!</h1>"

  """
  defmacro __using__(options) do
    path = Dict.fetch! options, :path

    quote do
      @path unquote(path)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    Module.register_attribute(env.module, :templates, accumulate: true)
    path = Module.get_attribute(env.module, :path)

    Template.precompile_all_from_root(path)
  end
end

