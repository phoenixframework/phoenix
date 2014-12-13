defmodule Phoenix.Template do
  @moduledoc """
  Templates are used by Phoenix on rendering.

  Since many views require rendering large contents, for example
  a whole HTML file, it is common to put those files in the file
  system into a particular directory, typically "web/templates".

  This module provides conveniences for reading all files from a
  particular directory and embeding them into a single module.
  Imagine you have a directory with templates:

      # templates/foo.html.eex
      Hello <%= @name %>

      # templates.ex
      defmodule Templates do
        use Phoenix.Template, root: "templates"
      end

  Now the template foo can be directly rendered with:

      Templates.render("foo.html", %{name: "John Doe"})

  In practice though, developers rarely use `Phoenix.Template`
  directly. Instead they use `Phoenix.View` which wraps the template
  functionality and add some extra conveniences.

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

  @encoders [html: Phoenix.HTML.Engine, json: Poison]
  @engines  [eex: Phoenix.Template.EExEngine, exs: Phoenix.Template.ExsEngine]

  defmodule UndefinedError do
    @moduledoc """
    Exception raised when a template cannot be found.
    """
    defexception [:available, :template, :module, :root]

    def message(exception) do
      "Could not render #{inspect exception.template} for #{inspect exception.module}, "
        <> "please define a clause for render/2 or define a template at "
        <> "#{inspect Path.relative_to_cwd exception.root}. "
        <> available_templates(exception.available)
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
    path = Dict.fetch! options, :root

    quote do
      @template_root Path.relative_to_cwd(unquote(path))
      @before_compile unquote(__MODULE__)

      @doc """
      Renders the given template locally.
      """
      def render(template, assigns \\ %{})
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    root = Module.get_attribute(env.module, :template_root)

    pairs = for path <- find_all(root) do
      compile(path, root)
    end

    names = Enum.map(pairs, &elem(&1, 0))
    codes = Enum.map(pairs, &elem(&1, 1))

    # We are using line -1 because we don't want warnings coming from
    # render/2 to be reported in case the user has already defined a
    # catch all render/2 clause.
    quote line: -1 do
      unquote(codes)

      def render(template, _assign) do
        raise UndefinedError,
          available: unquote(names),
          template: template,
          root: @template_root,
          module: __MODULE__
      end

      @doc """
      Returns true whenever the list of templates change in the filesystem.
      """
      def __phoenix_recompile__?, do: unquote(hash(root)) != Template.hash(@template_root)
    end
  end

  @doc """
  Returns the format encoder for the given template name.
  """
  @spec format_encoder(name) :: module | nil
  def format_encoder(template_name) when is_binary(template_name) do
    Map.get(compiled_format_encoders, Path.extname(template_name))
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
      raise "could not load #{name} configuration for Phoenix." <>
            " Was the :phoenix application started?"
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

      iex> Phoenix.Template.module_to_template_root(MyApp.UserView, "View")
      "user"

      iex> Phoenix.Template.module_to_template_root(MyApp.Admin.User, "View")
      "admin/user"

  """
  def module_to_template_root(module, suffix) do
    module
    |> Phoenix.Naming.unsuffix(suffix)
    |> Module.split
    |> tl
    |> Enum.map(&Phoenix.Naming.underscore/1)
    |> Path.join
  end

  @doc """
  Returns all template paths in a given template root.
  """
  @spec find_all(root) :: [path]
  def find_all(root) do
    extensions = engines |> Map.keys() |> Enum.join(",")
    Path.wildcard("#{root}/*.{#{extensions}}")
  end

  @doc """
  Returns the hash of all template paths in the given root.

  Used by Phoenix to check if a given root path requires recompilation.
  """
  @spec hash(root) :: binary
  def hash(root) do
    find_all(root)
    |> Enum.sort
    |> :erlang.md5
  end

  defp compile(path, root) do
    name   = template_path_to_name(path, root)
    defp   = String.to_atom(name)
    ext    = Path.extname(path) |> String.lstrip(?.) |> String.to_atom
    engine = engines()[ext]
    quoted = engine.compile(path, name)

    {name, quote do
      @file unquote(path)
      @external_resource unquote(path)

      defp unquote(defp)(var!(assigns)) do
        _ = var!(assigns)
        unquote(quoted)
      end

      def render(unquote(name), assigns) do
        unquote(defp)(assigns)
      end
    end}
  end
end

