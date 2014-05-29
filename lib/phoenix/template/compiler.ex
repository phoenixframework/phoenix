defmodule Phoenix.Template.Compiler do
  alias Phoenix.Template
  alias Phoenix.Template.UndefinedError
  alias Phoenix.Mime
  alias Plug.Conn

  @moduledoc """
  Precompiles EEx templates into module and provides `render` support

  Examples

  defmodule MyApp.Templates do
    use Phoenix.Template.Compiler, path: Path.join([__DIR__, "templates"])
  end

  From outside Controller
  iex> MyApp.Templates.render("show.html", message: "Hello!")
  "<h1>Hello!</h1>"

  From within Controller
  def show(conn) do
    render conn, "pages/home", title: "Home"
  end

  def show(conn) do
    render conn, "pages/home", layout: false, title: "Home"
  end

  """
  defmacro __using__(options) do
    path = Dict.fetch! options, :path

    quote do
      require EEx
      import unquote(__MODULE__)
      @path unquote(path)
      @before_compile unquote(__MODULE__)

      @doc """
      Renders template to string and sends html response when providing Conn

      * template - The full or partial template without extension to render
                   based on content type, ie."users/show", "users/show.html"
      * assigns - The optional Dict of template assigns
        * layout - The optional String layout, ie "application", false

      """
      # def render(template, assigns) when is_binary(template) do
      #   assigns   = Dict.put_new(assigns, :layout, "application.html")
      #   {:safe, content} = apply(__MODULE__, String.to_atom(template), [assigns])

      #   content
      # end
      # def render(conn, template, assigns) do
      #   content_type = Enum.at(Conn.get_req_header(conn, "content-type"), 0) || "text/html"
      #   IO.puts "CONTENT TYPE: #{inspect content_type}"
      #   render(conn, content_type, template, assigns)
      # end
      # def render(conn, content_type, template, assigns) do
      #   extension = Mime.ext_from_type(content_type) || ""
      #   assigns   = Dict.merge(conn.assigns, assigns)
      #   assigns   = Dict.put_new(assigns, :layout, "application" <> extension)
      #   tpl_func  = template <> extension
      #   {:safe, content} = apply(__MODULE__, String.to_atom(tpl_func), [assigns])

      #   Phoenix.Controller.html(conn, content)
      # end
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
        {:safe, render("layouts/#{layout}", layout_assigns)}
      else
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
      def render(undefined_template, _assign) do
        raise %UndefinedError{message: "No such template \"#{undefined_template}\""}
      end
    end
  end
end

