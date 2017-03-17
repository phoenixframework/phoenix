defmodule Mix.Phoenix do
  # Conveniences for Phoenix tasks.
  @moduledoc false

  @doc """
  Evals EEx files from source dir.

  Files are evaluated against EEx according to
  the given binding.
  """
  def eval_from(apps, source_file_path, binding) do
    sources = Enum.map(apps, &to_app_source(&1, source_file_path))

    content =
      Enum.find_value(sources, fn source ->
        File.exists?(source) && File.read!(source)
      end) || raise "could not find #{source_file_path} in any of the sources"

    EEx.eval_string(content, binding)
  end

  @doc """
  Copies files from source dir to target dir
  according to the given map.

  Files are evaluated against EEx according to
  the given binding.
  """
  def copy_from(apps, source_dir, target_dir, binding, mapping) when is_list(mapping) do
    roots = Enum.map(apps, &to_app_source(&1, source_dir))

    for {format, source_file_path, target_file_path} <- mapping do
      source =
        Enum.find_value(roots, fn root ->
          source = Path.join(root, source_file_path)
          if File.exists?(source), do: source
        end) || raise "could not find #{source_file_path} in any of the sources"

      target = Path.join(target_dir, target_file_path)

      case format do
        :text -> Mix.Generator.create_file(target, File.read!(source))
        :eex  -> Mix.Generator.create_file(target, EEx.eval_file(source, binding))
        :new_eex ->
          if File.exists?(target) do
            :ok
          else
            Mix.Generator.create_file(target, EEx.eval_file(source, binding))
          end
      end
    end
  end

  defp to_app_source(path, source_dir) when is_binary(path),
    do: Path.join(path, source_dir)
  defp to_app_source(app, source_dir) when is_atom(app),
    do: Application.app_dir(app, source_dir)

  @doc """
  Inflect path, scope, alias and more from the given name.

      iex> Mix.Phoenix.inflect("user")
      [alias: "User",
       human: "User",
       base: "Phoenix",
       web_module: "Phoenix.Web",
       module: "Phoenix.User",
       scoped: "User",
       singular: "user",
       path: "user"]

      iex> Mix.Phoenix.inflect("Admin.User")
      [alias: "User",
       human: "User",
       base: "Phoenix",
       web_module: "Phoenix.Web",
       module: "Phoenix.Admin.User",
       scoped: "Admin.User",
       singular: "user",
       path: "admin/user"]

      iex> Mix.Phoenix.inflect("Admin.SuperUser")
      [alias: "SuperUser",
       human: "Super user",
       base: "Phoenix",
       web_module: "Phoenix.Web",
       module: "Phoenix.Admin.SuperUser",
       scoped: "Admin.SuperUser",
       singular: "super_user",
       path: "admin/super_user"]
  """
  def inflect(singular) do
    base       = Mix.Phoenix.base
    web_module = base |> web_module() |> inspect()
    scoped     = Phoenix.Naming.camelize(singular)
    path       = Phoenix.Naming.underscore(scoped)
    singular   = String.split(path, "/") |> List.last
    module     = Module.concat(base, scoped) |> inspect
    alias      = String.split(module, ".") |> List.last
    human      = Phoenix.Naming.humanize(singular)

    [alias: alias,
     human: human,
     base: base,
     web_module: web_module,
     module: module,
     scoped: scoped,
     singular: singular,
     path: path]
  end

  @doc """
  Checks the availability of a given module name.
  """
  def check_module_name_availability!(name) do
    name = Module.concat(Elixir, name)
    if Code.ensure_loaded?(name) do
      Mix.raise "Module name #{inspect name} is already taken, please choose another name"
    end
  end

  @doc """
  Returns the module base name based on the configuration value.

      config :my_app
        namespace: My.App

  """
  def base do
    app = otp_app()

    case Application.get_env(app, :namespace, app) do
      ^app -> app |> to_string |> Phoenix.Naming.camelize()
      mod  -> mod |> inspect()
    end
  end

  @doc """
  Returns the otp app from the Mix project configuration.
  """
  def otp_app do
    Mix.Project.config |> Keyword.fetch!(:app)
  end

  @doc """
  Returns all compiled modules in a project.
  """
  def modules do
    Mix.Project.compile_path
    |> Path.join("*.beam")
    |> Path.wildcard
    |> Enum.map(&beam_to_module/1)
  end

  defp beam_to_module(path) do
    path |> Path.basename(".beam") |> String.to_atom()
  end

  @doc """
  The paths to look for template files for generators.

  Defaults to checking the current app's priv directory,
  and falls back to phoenix's priv directory.
  """
  def generator_paths do
    [".", :phoenix]
  end

  @doc """
  Checks if the given `app_path` is inside an umbrella.
  """
  def in_umbrella?(app_path) do
    umbrella = Path.expand(Path.join [app_path, "..", ".."])
    mix_path = Path.join(umbrella, "mix.exs")
    apps_path = Path.join(umbrella, "apps")
    File.exists?(mix_path) && File.exists?(apps_path)
  end

  @doc """
  Returns the web prefix to be used in generated file specs.
  """
  def web_prefix do
    app = to_string(otp_app())
    if in_umbrella?(File.cwd!()) do
      Path.join("lib", app)
    else
      Path.join(["lib", app, "web"])
    end
  end

  @doc """
  Returns the test prefix to be used in generated file specs.
  """
  def test_prefix do
    if in_umbrella?(File.cwd!()) do
      "test"
    else
      "test/web"
    end
  end

  @doc """
  Returns the web path of the file in the application.
  """
  def web_path(rel_path) do
    Path.join(web_prefix(), rel_path)
  end

  @doc """
  Prompts to continue if any files exist.
  """
  def prompt_for_conflicts(generator_files) do
    file_paths = Enum.map(generator_files, fn {_, _, path} -> path end)

    case Enum.filter(file_paths, &File.exists?(&1)) do
      [] -> :ok
      conflicts ->
        Mix.shell.info"""
        The following files conflict with new files to be generated:

        #{conflicts |> Enum.map(&"  * #{&1}") |> Enum.join("\n")}

        See the --web option to namespace similarly named resources
        """
        unless Mix.shell.yes?("Proceeed with interactive overwrite?") do
          System.halt()
        end
    end
  end

  defp web_module(base) do
    if base |> to_string() |> String.ends_with?(".Web") do
      Module.concat(base, nil)
    else
      Module.concat(base, "Web")
    end
  end
end
