defmodule Mix.Phoenix do
  # Conveniences for Phoenix tasks.
  @moduledoc false

  @doc """
  Retrieves the project router based on the application name.
  """
  def router do
    Module.concat(app_base, "Router")
  end

  @doc """
  Retrieves the project endpoint based on the application name.
  """
  def endpoint do
    Module.concat(app_base, "Endpoint")
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

  defp app_base do
    Mix.Project.config
    |> Keyword.fetch!(:app)
    |> to_string
    |> Phoenix.Naming.camelize
  end

  defp beam_to_module(path) do
    path |> Path.basename(".beam") |> String.to_atom()
  end
end
