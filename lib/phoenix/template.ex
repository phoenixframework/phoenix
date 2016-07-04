defmodule Phoenix.Template do
  @moduledoc """
  Templates are used by Phoenix on rendering.

  Since many views require rendering large contents, for example
  a whole HTML file, it is common to put those files in the file
  system into a particular directory, typically "web/templates".

  This module provides conveniences for reading all files from a
  particular directory and embedding them into a single module.
  Imagine you have a directory with templates:

      # templates/foo.html.eex
      Hello <%= @name %>

      # templates.ex
      defmodule Templates do
        use Phoenix.Template, root: "templates"
      end

  Now the template foo can be directly rendered with:

      Templates.render("foo.html", %{name: "John Doe"})

  ## Options

    * `:root` - the root template path to find templates
    * `:pattern` - the wildcard pattern to apply to the root
      when finding templates. Default `"*"`

  ## Rendering

  In some cases, you will want to overide the `render/2` clause
  to compose the assigns for the template before rendering. In such
  cases, you can render the template directly by calling the generated
  private function `render_template/2`. For example:

      # templates/foo.html.eex
      Hello <%= @name %>

      # templates.ex
      defmodule Templates do
        use Phoenix.Template, root: "templates"

        def render("foo.html", %{name: name}) do
          render_template("foo.html", %{name: String.upcase(name)})
        end
      end

  In practice, developers rarely use `Phoenix.Template`
  directly. Instead they use `Phoenix.View` which wraps the template
  functionality and adds some extra conveniences.

  ## Terminology

  Here is a quick introduction into Phoenix templates terms:

    * template name - is the name of the template as
      given by the user, without the template engine extension,
      for example: "users.html"

    * template path - is the complete path of the template
      in the filesystem, for example, "path/to/users.html.eex"

    * template root - the directory were templates are defined

    * template engine - a module that receives a template path
      and transforms its source code into Elixir quoted expressions.

  ## Custom Template Engines

  Phoenix supports custom template engines. Engines tell
  Phoenix how to convert a template path into quoted expressions.
  Please check `Phoenix.Template.Engine` for more information on
  the API required to be implemented by custom engines.

  Once a template engine is defined, you can tell Phoenix
  about it via the template engines option:

      config :phoenix, :template_engines,
        eex: Phoenix.Template.EExEngine,
        exs: Phoenix.Template.ExsEngine

  ## Format encoders

  Besides template engines, Phoenix has the concept of format encoders.
  Format encoders work per format and are responsible for encoding a
  given format to string once the view layer finishes processing.

  A format encoder must export a function called `encode_to_iodata!/1`
  which receives the rendering artifact and returns iodata.

  New encoders can be added via the format encoder option:

      config :phoenix, :format_encoders,
        html: Phoenix.HTML.Engine,
        json: Poison

  """

  @type name :: binary
  @type path :: binary
  @type root :: binary

  alias Phoenix.Template

  @encoders [html: Phoenix.Template.HTML, json: Poison, js: Phoenix.Template.HTML]
  @engines  [eex: Phoenix.Template.EExEngine, exs: Phoenix.Template.ExsEngine]
  @default_pattern "*"

  defmodule UndefinedError do
    @moduledoc """
    Exception raised when a template cannot be found.
    """
    defexception [:available, :template, :module, :root, :assigns, :pattern]

    def message(exception) do
      "Could not render #{inspect exception.template} for #{inspect exception.module}, "
        <> "please define a matching clause for render/2 or define a template at "
        <> "#{inspect Path.relative_to_cwd exception.root}. "
        <> available_templates(exception.available)
        <> "\nAssigns:\n\n"
        <> inspect(exception.assigns)
        <> "\n"
    end

    defp available_templates([]), do: "No templates were compiled for this module."
    defp available_templates(available) do
      "The following templates were compiled:\n\n"
        <> Enum.map_join(available, "\n", &"* #{&1}")
        <> "\n"
    end
  end

  @doc false
  defmacro __using__(options) do
    quote bind_quoted: [options: options], unquote: true do
      root = Keyword.fetch!(options, :root)
      @phoenix_root Path.relative_to_cwd(root)
      @phoenix_pattern Keyword.get(options, :pattern, unquote(@default_pattern))
      @before_compile unquote(__MODULE__)

      @doc """
      Renders the given template locally.
      """
      def render(template, assigns \\ %{})

      def render(module, template) when is_atom(module) do
        Phoenix.View.render(module, template, %{})
      end

      def render(template, _assigns) when not is_binary(template) do
        raise ArgumentError, "render/2 expects template to be a string, got: #{inspect template}"
      end

      def render(template, assigns) when not is_map(assigns) do
        render(template, Enum.into(assigns, %{}))
      end

      @doc """
      Callback invoked when no template is found.
      By default it raises but can be customized
      to render a particular template.
      """
      @spec template_not_found(Phoenix.Template.name, map) :: no_return
      def template_not_found(template, assigns) do
        Template.raise_template_not_found(__MODULE__, template, assigns)
      end

      defoverridable [template_not_found: 2]
    end
  end

  @anno (if :erlang.system_info(:otp_release) >= '19' do
    [generated: true]
  else
    [line: -1]
  end)

  @doc false
  defmacro __before_compile__(env) do
    root    = Module.get_attribute(env.module, :phoenix_root)
    pattern = Module.get_attribute(env.module, :phoenix_pattern)

    pairs = for path <- find_all(root, pattern) do
      compile(path, root)
    end

    names = Enum.map(pairs, &elem(&1, 0))
    codes = Enum.map(pairs, &elem(&1, 1))

    # We are using @anno because we don't want warnings coming from
    # render/2 to be reported in case the user has defined a catch all
    # render/2 clause.
    quote @anno do
      unquote(codes)

      # Catch-all clause for rendering.
      def render(template, assigns) do
        render_template(template, assigns)
      end

      # Catch-all clause for template rendering.
      defp render_template(template, %{render_existing: {__MODULE__, template}}) do
        nil
      end

      defp render_template(template, %{template_not_found: __MODULE__} = assigns) do
        Template.raise_template_not_found(__MODULE__, template, assigns)
      end
      defp render_template(template, assigns) do
        template_not_found(template, Map.put(assigns, :template_not_found, __MODULE__))
      end

      @doc """
      Returns the template root alongside all templates.
      """
      def __templates__ do
        {@phoenix_root, @phoenix_pattern, unquote(names)}
      end

      @doc """
      Returns true whenever the list of templates changes in the filesystem.
      """
      def __phoenix_recompile__? do
        unquote(hash(root, pattern)) != Template.hash(@phoenix_root, @phoenix_pattern)
      end
    end
  end

  @doc """
  Returns the format encoder for the given template name.
  """
  @spec format_encoder(name) :: module | nil
  def format_encoder(template_name) when is_binary(template_name) do
    Map.get(compiled_format_encoders(), Path.extname(template_name))
  end

  defp compiled_format_encoders do
    case Application.fetch_env(:phoenix, :compiled_format_encoders) do
      {:ok, encoders} ->
        encoders
      :error ->
        encoders =
          @encoders
          |> Keyword.merge(raw_config(:format_encoders))
          |> Enum.filter(fn {_, v} -> v end)
          |> Enum.into(%{}, fn {k, v} -> {".#{k}", v} end)
        Application.put_env(:phoenix, :compiled_format_encoders, encoders)
        encoders
    end
  end

  @doc """
  Returns a keyword list with all template engines
  extensions followed by their modules.
  """
  @spec engines() :: %{atom => module}
  def engines do
    compiled_engines()
  end

  defp compiled_engines do
    case Application.fetch_env(:phoenix, :compiled_template_engines) do
      {:ok, engines} ->
        engines
      :error ->
        engines =
          @engines
          |> Keyword.merge(raw_config(:template_engines))
          |> Enum.filter(fn {_, v} -> v end)
          |> Enum.into(%{})
        Application.put_env(:phoenix, :compiled_template_engines, engines)
        engines
    end
  end

  defp raw_config(name) do
    Application.get_env(:phoenix, name) ||
      raise "could not load #{name} configuration for Phoenix. " <>
            "Please ensure you have listed :phoenix under :applications in your " <>
            "mix.exs file and have enabled the :phoenix compiler under :compilers, " <>
            "for example: [:phoenix] ++ Mix.compilers"
  end

  @doc """
  Converts the template path into the template name.

  ## Examples

      iex> Phoenix.Template.template_path_to_name(
      ...>   "lib/templates/admin/users/show.html.eex",
      ...>   "lib/templates")
      "admin/users/show.html"

  """
  @spec template_path_to_name(path, root) :: name
  def template_path_to_name(path, root) do
    path
    |> Path.rootname()
    |> Path.relative_to(root)
  end

  @doc """
  Converts a module, without the suffix, to a template root.

  ## Examples

      iex> Phoenix.Template.module_to_template_root(MyApp.UserView, MyApp, "View")
      "user"

      iex> Phoenix.Template.module_to_template_root(MyApp.Admin.User, MyApp, "View")
      "admin/user"

      iex> Phoenix.Template.module_to_template_root(MyApp.Admin.User, MyApp.Admin, "View")
      "user"

      iex> Phoenix.Template.module_to_template_root(MyApp.View, MyApp, "View")
      ""

      iex> Phoenix.Template.module_to_template_root(MyApp.View, MyApp.View, "View")
      ""

  """
  def module_to_template_root(module, base, suffix) do
    module
    |> Phoenix.Naming.unsuffix(suffix)
    |> Module.split
    |> Enum.drop(length(Module.split(base)))
    |> Enum.map(&Phoenix.Naming.underscore/1)
    |> join_paths
  end

  defp join_paths([]),    do: ""
  defp join_paths(paths), do: Path.join(paths)

  @doc """
  Returns all template paths in a given template root.
  """
  @spec find_all(root, pattern :: String.t) :: [path]
  def find_all(root, pattern \\ @default_pattern) do
    extensions = engines() |> Map.keys() |> Enum.join(",")

    root
    |> Path.join(pattern <> ".{#{extensions}}")
    |> Path.wildcard()
  end

  @doc """
  Returns the hash of all template paths in the given root.

  Used by Phoenix to check if a given root path requires recompilation.
  """
  @spec hash(root, pattern :: String.t) :: binary
  def hash(root, pattern \\ @default_pattern) do
    find_all(root, pattern)
    |> Enum.sort()
    |> :erlang.md5()
  end

  @doc false
  def raise_template_not_found(view_module, template, assigns) do
    {root, pattern, names} = view_module.__templates__()
    raise UndefinedError,
      assigns: assigns,
      available: names,
      template: template,
      root: root,
      pattern: pattern,
      module: view_module
  end

  defp compile(path, root) do
    name   = template_path_to_name(path, root)
    defp   = String.to_atom(name)
    ext    = Path.extname(path) |> String.lstrip(?.) |> String.to_atom
    engine = Map.fetch!(engines(), ext)
    quoted = engine.compile(path, name)

    {name, quote do
      @file unquote(path)
      @external_resource unquote(path)

      defp unquote(defp)(var!(assigns)) do
        _ = var!(assigns)
        unquote(quoted)
      end

      defp render_template(unquote(name), assigns) do
        unquote(defp)(assigns)
      end
    end}
  end
end
