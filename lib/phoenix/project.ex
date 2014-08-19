defmodule Phoenix.Project do
  alias Phoenix.Naming

  @doc """
  Returns the Applications name as an Atom, ie :phoenix
  """
  def app do
    Keyword.get Mix.Project.config, :app
  end

  @doc """
  Returns the "root" module of the Application, ie `MyApp`
  """
  def module_root do
    app
    |> to_string
    |> Naming.camelize
    |> String.to_atom
  end

  @doc """
  Returns all conventionally defined view modules and file paths in web/views

  ## Exampes

      iex> Project.module_root
      PageView
      iex> Project.view_modules
      {"web/views/page_view.ex", MyApp.Views.PageView}

  """
  def view_modules do
    "web/views/**/**.{ex, exs}"
    |> Path.wildcard
    |> Enum.map(&view_path_to_module(&1))
    |> Enum.filter(fn {_path, mod} -> Code.ensure_loaded?(mod) end)
  end

  defp view_path_to_module(rel_view_path) do
    module = rel_view_path
    |> String.replace(~r/(web\/views\/)|(\.ex)|(\.exs)/, "")
    |> String.split("/")
    |> Enum.map(&Phoenix.Naming.camelize(&1))
    |> Enum.join(".")

    {rel_view_path, Module.concat([module_root, module])}
  end
end
