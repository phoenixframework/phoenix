defmodule Phoenix.Template do
  @moduledoc """
  TODO: Talk about templates.

  ## Terminology

  Here is a quick introduction into Phoenix templates terms:

    * template name - is the name of the template as
      given by the user, without the template engine extension,
      for example: "users.html"

    * template path - is the complete path of the template
      in the filesystem, for example, "path/to/users.html.eex"

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
        haml: Calliope.PhoenixEngine

  Notice that all desired engines must be explicitly listed
  in the `:template_engines` configuration.

  ## Format encoders

  Besides template engines, Phoenix has the concept of format encoders.
  Format encoders work per format and are responsible for encoding a
  given format to string once the view layer finishes processing.

  A format encoder must export a function called `encode!/1` which
  receives the rendering artifact and returns a string.

  Phoenix ships with one formatter called `Phoenix.HTML.Safe` for `:html`
  templates which are responsible to guarantee the given output is HTML
  safe.

  New encoders can be added via the format encoders option:

      config :phoenix, :format_encoders,
        html: Phoenix.HTML.Safe

  Notice that all desired encoders must be explicitly listed
  in the `:format_encoders` configuration.
  """

  alias Phoenix.Template

  defmodule UndefinedError do
    defexception [:message]
    def exception(opts) do
      %UndefinedError{message: opts[:message]}
    end
  end

  @doc """
  Returns the format encoder for the given template name.
  """
  def format_encoder(template_name) when is_binary(template_name) do
    Map.get(compiled_format_encoders, Path.extname(template_name))
  end

  defp compiled_format_encoders do
    case Application.fetch_env(:phoenix, :compiled_format_encoders) do
      {:ok, encoders} ->
        encoders
      :error ->
        encoders = Enum.into(Application.get_env(:phoenix, :format_encoders),
                             %{}, fn {k, v} -> {".#{k}", v} end)
        Application.put_env(:phoenix, :compiled_format_encoders, encoders)
        encoders
    end
  end

  @doc """
  Converts the template file path into a function name

    * path - The String Path to the template file
    * template_root - The String Path of the template root diretory

  ## Examples

      iex> Template.func_name_from_path(
        "lib/templates/admin/users/show.html.eex",
        "lib/templates")
      "admin/users/show.html"

  """
  def func_name_from_path(path, template_root) do
    path
    |> String.replace(template_root, "")
    |> String.lstrip(?/)
    |> String.replace(Path.extname(path), "")
  end

  @doc """
  Returns List of template EEx template file paths
  """
  def find_all_from_root(template_root) do
    extensions = engine_extensions |> Enum.join(",")
    Path.wildcard("#{template_root}/**/*.{#{extensions}}")
  end

  @doc """
  Returns the sha hash of the list of all file names in the given path
  """
  def path_hash(template_root) do
    "#{template_root}/**/*"
    |> Path.wildcard
    |> Enum.sort
    |> sha
  end
  def sha(data), do: :crypto.hash(:sha, data)

  @doc """
  Precompiles all templates witin `@path` directory as function definitions

  Injects a `recompile?` function to determine if the directory contents have
  changed and the module requires recompilation. Uses sha hash of dir contents.

  See `precompile/2` for more information

  Returns AST of `render/2` functions and `recompile?/0`
  """
  def precompile_all_from_root(path) do
    renders_ast = for file_path <- find_all_from_root(path) do
      precompile(file_path, path)
    end

    quote do
      unquote(renders_ast)
      def render(template), do: render(template, [])
      def render(undefined_template, _assign) do
        raise UndefinedError, message: """
        Could not render "#{undefined_template}" for #{inspect(__MODULE__)}, please define a clause for render/2 or define a template at "#{@path}".

        The following templates were compiled: "#{Enum.join @templates, ", "}"
        """
      end

      @doc "Returns true if list of directory files has changed"
      def phoenix_recompile?, do: unquote(path_hash(path)) != Template.path_hash(@path)
    end
  end

  @doc """
  Precompiles the String file_path into a `render/2` function defintion, using
  an engine configured for the template file extension
  """
  def precompile(file_path, root_path) do
    name   = func_name_from_path(file_path, root_path)
    ext    = Path.extname(file_path) |> String.lstrip(?.) |> String.to_atom
    engine = Application.get_env(:phoenix, :template_engines)[ext] ||
               raise "could not find template engine for extension #{inspect ext}"
    quoted = engine.compile(file_path, name)

    quote do
      @file unquote(file_path)
      @templates unquote(name)
      @external_resource unquote(file_path)

      def render(unquote(name), var!(assigns)) do
        _ = var!(assigns)
        unquote(quoted)
      end
    end
  end

  defp engine_extensions do
    (Application.get_env(:phoenix, :template_engines) ||
      raise "could not load template_engines configuration for Phoenix." <>
            "Was the Phoenix started?") |> Dict.keys
  end
end

