defmodule Mix.Phoenix do
  # Conveniences for Phoenix tasks.
  @moduledoc false

  @doc """
  Returns the module base name based on the configuration value.

      config :my_app
        phoenix_namespace: My.App

  """
  def base do
    app = Mix.Project.config |> Keyword.fetch!(:app)

    case Application.get_env(app, :phoenix_namespace, app) do
      ^app -> app |> to_string |> Phoenix.Naming.camelize
      mod  -> mod |> module_to_base_name
    end
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
