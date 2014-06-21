defmodule Phoenix.Template.Compiler do
  alias Phoenix.Template
  alias Phoenix.Template.UndefinedError

  @moduledoc """
  Precompiles EEx templates into view module and provides `render` support

  Examples

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

  Examples

  <%= within @layout do %>
    <h1>Home Page</h1>
  <% end %>

  """
  defmacro within(layout, do: inner) do
    quote bind_quoted: [layout: layout, inner: inner] do
      case layout do
        {module, layout} ->
          layout_assigns = Dict.merge(var!(:assigns), inner: inner, within: nil)
          {:safe, module.render(layout, layout_assigns)}
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
      name    = Template.func_name_from_path(file_path, path)
      content = Template.read!(file_path)
      quote do
        def render(unquote(name)), do: render(unquote(name), [])
        def render(unquote(name), assigns) do
          apply(__MODULE__, :"#{unquote(name)}", [assigns])
        end

        @file unquote(file_path)
        EEx.function_from_string(:def, :"#{unquote(name)}", unquote(content), [:assigns],
                                 engine: Phoenix.Html.Engine)
      end
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

