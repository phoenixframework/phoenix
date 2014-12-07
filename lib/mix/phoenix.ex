defmodule Mix.Phoenix do
  # Conveniences for Phoenix tasks.
  @moduledoc false

  @doc """
  Retrieves the project router based on the application name
  """
  def router do
    Mix.Project.config
    |> Keyword.fetch!(:app)
    |> to_string
    |> Phoenix.Naming.camelize
    |> Module.concat("Router")
  end

  @doc """
  Returns all modules in a project
  """
  def modules do
    Mix.Project.compile_path
    |> Path.join("*.beam")
    |> Path.wildcard
    |> Enum.map(&beam_to_module/1)
  end

  @doc """
  Copy's the files from one directory to the specified directory, renaming files as needed.
  """
  def copy_from(source_dir, target_dir, file_name_template, fun) do
    source_paths =
      source_dir
      |> Path.join("**/*")
      |> Path.wildcard(match_dot: true)

    for source_path <- source_paths do
      target_path = make_destination_path(source_path, source_dir,
                                          target_dir, file_name_template)

      unless File.dir?(source_path) do
        contents = fun.(source_path)
        Mix.Generator.create_file(target_path, contents)
      end
    end
  end

  @doc """
  Creates a file or folder, renaming where applicable.
  """
  def make_destination_path(source_path, source_dir, target_dir, {string_to_replace, name_of_generated}) do
    target_path =
      source_path
      |> String.replace(string_to_replace, String.downcase(name_of_generated))
      |> Path.relative_to(source_dir)
    Path.join(target_dir, target_path)
  end

  defp beam_to_module(path) do
    path |> Path.basename(".beam") |> String.to_atom()
  end
end
