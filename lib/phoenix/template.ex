defmodule Phoenix.Template do
  @moduledoc """
  Templates are used by Phoenix when rendering responses.

  Since many views render significant content, for example a whole
  HTML file, it is common to put these files into a particular directory,
  typically "APP_web/templates".

  This module provides conveniences for reading all files from a
  particular directory and embedding them into a single module.
  Imagine you have a directory with templates:

      # templates/foo.html.eex
      Hello <%= @name %>

      # templates.ex
      defmodule Templates do
        use Phoenix.Template, root: "templates"

        def render(template, assigns) do
          render_template(template, assigns)
        end
      end

  `Phoenix.Template` will define a private function named `render_template/2`
  with one clause per file system template. We expose this private function
  via `render/2`, which can be invoked as:

      Templates.render("foo.html", %{name: "John Doe"})

  In practice, developers rarely use `Phoenix.Template` directly.
  Instead they use `Phoenix.View` which wraps the template functionality
  and adds some extra conveniences.

  ## Options

    * `:root` - the root template path to find templates
    * `:pattern` - the wildcard pattern to apply to the root
      when finding templates. Default `"*"`
    * `:template_engines` - a map of template engines extensions
      to template engine handlers

  ## Terminology

  Here is a quick introduction into Phoenix templates terms:

    * template name - is the name of the template as
      given by the user, without the template engine extension,
      for example: "users.html"

    * template path - is the complete path of the template
      in the filesystem, for example, "path/to/users.html.eex"

    * template root - the directory where templates are defined

    * template engine - a module that receives a template path
      and transforms its source code into Elixir quoted expressions

  ## Custom Template Engines

  Phoenix supports custom template engines. Engines tell
  Phoenix how to convert a template path into quoted expressions.
  See `Phoenix.Template.Engine` for more information on
  the API required to be implemented by custom engines.

  Once a template engine is defined, you can tell Phoenix
  about it via the template engines option:

      config :phoenix, :template_engines,
        eex: Phoenix.Template.EExEngine,
        exs: Phoenix.Template.ExsEngine

  If you want to support a given engine only on a certain template,
  you can pass it as an option on `use Phoenix.Template`:

      use Phoenix.Template, template_engines: %{
        foo: Phoenix.Template.FooEngine
      }

  ## Format encoders

  Besides template engines, Phoenix has the concept of format encoders.
  Format encoders work per format and are responsible for encoding a
  given format to string once the view layer finishes processing.

  A format encoder must export a function called `encode_to_iodata!/1`
  which receives the rendering artifact and returns iodata.

  New encoders can be added via the format encoder option:

      config :phoenix, :format_encoders,
        html: Phoenix.HTML.Engine

  """

  @type name :: binary
  @type path :: binary
  @type root :: binary

  alias Phoenix.Template

  @engines [
    eex: Phoenix.Template.EExEngine,
    exs: Phoenix.Template.ExsEngine,
    leex: Phoenix.LiveView.Engine
  ]

  @default_pattern "*"
  @private_assigns [:__phx_template_not_found__]

  defmodule UndefinedError do
    @moduledoc """
    Exception raised when a template cannot be found.
    """
    defexception [:available, :template, :module, :root, :assigns, :pattern]

    def message(exception) do
      "Could not render #{inspect exception.template} for #{inspect exception.module}, "
        <> "please define a matching clause for render/2 or define a template at "
        <> "#{inspect Path.join(Path.relative_to_cwd(exception.root), exception.pattern)}. "
        <> available_templates(exception.available)
        <> "\nAssigns:\n\n"
        <> inspect(exception.assigns)
        <> "\n\nAssigned keys: #{inspect Map.keys(exception.assigns)}\n"
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
      @phoenix_template_engines Enum.into(Keyword.get(options, :template_engines, %{}), Template.engines())
      @before_compile unquote(__MODULE__)

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

  @doc false
  defmacro __before_compile__(env) do
    root    = Module.get_attribute(env.module, :phoenix_root)
    pattern = Module.get_attribute(env.module, :phoenix_pattern)
    engines = Module.get_attribute(env.module, :phoenix_template_engines)

    pairs =
      for path <- find_all(root, pattern, engines) do
        compile(path, root, engines)
      end

    names = Enum.map(pairs, &elem(&1, 0))
    codes = Enum.map(pairs, &elem(&1, 1))

    quote do
      unquote(codes)

      # Catch-all clause for template rendering.
      defp render_template(template, %{__phx_render_existing__: {__MODULE__, template}}) do
        nil
      end

      defp render_template(template, %{__phx_template_not_found__: __MODULE__} = assigns) do
        Template.raise_template_not_found(__MODULE__, template, assigns)
      end

      defp render_template(template, assigns) do
        template_not_found(template, Map.put(assigns, :__phx_template_not_found__, __MODULE__))
      end

      @doc false
      def __templates__ do
        {@phoenix_root, @phoenix_pattern, unquote(names)}
      end

      @doc false
      def __phoenix_recompile__? do
        unquote(hash(root, pattern, engines)) != Template.hash(@phoenix_root, @phoenix_pattern, @phoenix_template_engines)
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
          default_encoders()
          |> Keyword.merge(raw_config(:format_encoders))
          |> Enum.filter(fn {_, v} -> v end)
          |> Enum.into(%{}, fn {k, v} -> {".#{k}", v} end)
        Application.put_env(:phoenix, :compiled_format_encoders, encoders)
        encoders
    end
  end

  defp default_encoders do
    [html: Phoenix.HTML.Engine, json: Phoenix.json_library(), js: Phoenix.HTML.Engine]
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
  @spec find_all(root, pattern :: String.t(), %{atom => module}) :: [path]
  def find_all(root, pattern \\ @default_pattern, engines \\ engines()) do
    extensions = engines |> Map.keys() |> Enum.join(",")

    root
    |> Path.join(pattern <> ".{#{extensions}}")
    |> Path.wildcard()
  end

  @doc """
  Returns the hash of all template paths in the given root.

  Used by Phoenix to check if a given root path requires recompilation.
  """
  @spec hash(root, pattern :: String.t, %{atom => module}) :: binary
  def hash(root, pattern \\ @default_pattern, engines \\ engines()) do
    find_all(root, pattern, engines)
    |> Enum.sort()
    |> :erlang.md5()
  end

  @doc false
  def raise_template_not_found(view_module, template, assigns) do
    {root, pattern, names} = view_module.__templates__()
    raise UndefinedError,
      assigns: Map.drop(assigns, @private_assigns),
      available: names,
      template: template,
      root: root,
      pattern: pattern,
      module: view_module
  end

  defp compile(path, root, engines) do
    name   = template_path_to_name(path, root)
    defp   = String.to_atom(name)
    ext    = Path.extname(path) |> String.trim_leading(".") |> String.to_atom
    engine = Map.fetch!(engines, ext)
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
