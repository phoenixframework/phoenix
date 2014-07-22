defmodule Phoenix.Template.Compiler do
  alias Phoenix.Template
  alias Phoenix.Template.UndefinedError

  @moduledoc """
  Precompiles EEx templates into view module and provides `render` support

  Uses Mix config `:template_engines` dict to map template extensions to
  Template Engine compilers.

  ## Template Engines

  Engines need only to support precompiling a template function, of the form:

      def precompile(file_path, func_name)

  The `precompile/2` function must return an AST for for a `render/2` function:

      def render(func_name, assigns \\ [])

  See `Template.EExEngine` for an example engine implementation.


  ## Template Engine Configuration

  By default, `eex` and `haml` are supported (with an optional `Calliope` dep)
  To Configure a third-party Phoenix Template Engine, simply add the
  extenion and module to your Mix Config, ie:

      config :phoenix, :template_engines,
        slim: Slim.PhoenixEngine

  ## Examples

      defmodule MyApp.Views do
        use Phoenix.Template.Compiler, path: Path.join([__DIR__, "templates"])
      end

      iex> MyApp.Views.render("show.html", message: "Hello!")
      "<h1>Hello!</h1>"

  """
  defmacro __using__(options) do
    path = Dict.fetch! options, :path

    quote do
      require EEx
      import unquote(__MODULE__)
      @path unquote(path)
      @before_compile unquote(__MODULE__)
    end
  end

  @doc """
  Renders the layout, assigning `@inner` as the provided nested template
  If layout is not provided, simply renders the nested contents without layout

  ## Examples

      <%= within @layout do %>
        <h1>Home Page</h1>
      <% end %>

  """
  defmacro within(layout, do: inner) do
    quote bind_quoted: [layout: layout, inner: inner] do
      case layout do
        {module, layout} ->
          layout_assigns = Dict.merge(var!(assigns), inner: inner, within: nil)
          module.render(layout, layout_assigns)
        nil ->
          inner
      end
    end
  end

  defmacro __before_compile__(env) do
    path = Module.get_attribute(env.module, :path)
    unless File.exists?(path) do
      raise %UndefinedError{message: "No such template directory: #{path}"}
    end

    renders_ast = for file_path <- Template.find_all_from_root(path) do
      Template.precompile(file_path, path)
    end

    quote do
      unquote(renders_ast)
      def render(undefined_template), do: render(undefined_template, [])
      def render(undefined_template, _assign) do
        raise %UndefinedError{message: "No such template \"#{undefined_template}\""}
      end
    end
  end

end

