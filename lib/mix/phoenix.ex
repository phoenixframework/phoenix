defmodule Mix.Phoenix do
  # Conveniences for Phoenix tasks.
  @moduledoc false

  @doc """
  Returns the module base name based on the application name.
  """
  def base do
    Mix.Project.config
    |> Keyword.fetch!(:app)
    |> to_string
    |> Phoenix.Naming.camelize
  end

  @doc """
  Retrieves the project endpoints based on the application name.
  """
  def endpoints(args) do
    cond do
      args != [] ->
        Enum.map(args, &Module.concat("Elixir", &1))
      endpoints = Mix.Project.config[:endpoints] ->
        endpoints
      Mix.Project.umbrella? ->
        Mix.raise "No endpoints available. Umbrella applications must add endpoints in the project " <>
                  "configuration or pass them explicitly via command line arguments"
      true ->
        [Module.concat(base(), Endpoint)]
    end
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
