defmodule Mix.Phoenix do
  # Conveniences for Phoenix tasks.
  @moduledoc false

  @doc """
  Returns the module base name based on the application name.
  """
  def base do
    {:ok, {mod, _}} =
      Mix.Project.config
      |> Keyword.fetch!(:app)
      |> :application.get_key(:mod)
    module_to_base_name(mod)
  end

  defp module_to_base_name(mod) do
    mod |> to_string |> String.replace("Elixir.", "")
  end

  @doc """
  Returns all modules in a project.
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
