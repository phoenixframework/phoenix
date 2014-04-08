defmodule Phoenix.Template.Compiler do
  alias Phoenix.Template

  defmacro __using__(options) do
    path = Dict.fetch! options, :path

    quote do
      require EEx
      import unquote(__MODULE__)
      @path unquote(path)
      @before_compile unquote(__MODULE__)

      def render(template, assigns \\ []) do
        assigns = Dict.put_new(assigns, :layout, "application.html")
        {:safe, content} = apply(__MODULE__, binary_to_atom(template), [assigns])

        content
      end
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
      if layout do
        layout_assigns = Dict.merge(var!(:assigns), inner: inner)
        apply(__MODULE__, binary_to_atom("layouts/#{layout}"), [layout_assigns])
      else
        inner
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      unless File.exists?(@path), do: raise "No such template directory: #{@path}"

      Enum.each Template.find_all_from_root(@path), fn file_path ->
        name    = Template.func_name_from_path(file_path, @path)
        content = Template.read!(file_path)

        EEx.function_from_string(:def, :"#{name}", content, [:assigns],
                                 engine: Phoenix.Html.Engine)
      end
    end
  end
end

