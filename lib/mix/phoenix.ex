defmodule Mix.Phoenix do
  # Conveniences for Phoenix tasks.
  @moduledoc false

  @doc """
  Copies files from source dir to target dir
  according to the given map.

  Files are evaluated against EEx according to
  the given binding.
  """
  def copy_from(source_dir, target_dir, binding, mapping) when is_list(mapping) do
    for {format, source_file_path, target_file_path} <- mapping do
      source = Path.join(source_dir, source_file_path)
      target = Path.join(target_dir, target_file_path)

      contents =
        case format do
          :text -> File.read!(source)
          :eex  -> EEx.eval_file(source, binding)
        end

      Mix.Generator.create_file(target, contents)
    end
  end

  @doc """
  Inflect path, scope, alias and more from the given name.

      iex> Mix.Phoenix.inflect("user")
      [alias: "User",
       base: "Phoenix",
       module: "Phoenix.User",
       scoped: "User",
       singular: "user",
       path: "user"]

      iex> Mix.Phoenix.inflect("Admin.User")
      [alias: "User",
       base: "Phoenix",
       module: "Phoenix.Admin.User",
       scoped: "Admin.User",
       singular: "user",
       path: "admin/user"]
  """
  def inflect(singular) do
    base     = Mix.Phoenix.base
    scoped   = Phoenix.Naming.camelize(singular)
    path     = Phoenix.Naming.underscore(scoped)
    singular = String.split(path, "/") |> List.last
    module   = Module.concat(base, scoped) |> inspect
    alias    = String.split(module, ".") |> List.last

    [alias: alias,
     base: base,
     module: module,
     scoped: scoped,
     singular: singular,
     path: path]
  end

  @doc """
  Returns the module base name based on the configuration value.

      config :my_app
        app_namespace: My.App

  """
  def base do
    app = Mix.Project.config |> Keyword.fetch!(:app)

    case Application.get_env(app, :app_namespace, app) do
      ^app -> app |> to_string |> Phoenix.Naming.camelize
      mod  -> mod |> inspect
    end
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
end
