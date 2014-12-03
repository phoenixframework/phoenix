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

  defp beam_to_module(path) do
    path |> Path.basename(".beam") |> String.to_atom()
  end

  @doc """
  Checks to see if an app has phoenix in its dependency list.
  """
  def is_phoenix_app? do
    Mix.Project.config
    |> Keyword.fetch!(:deps)
    |> Keyword.has_key?(:phoenix)
  end
end
