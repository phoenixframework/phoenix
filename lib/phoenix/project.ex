defmodule Phoenix.Project do
  alias Phoenix.Naming

  @moduledoc """
  Handles lookup of current Mix project and modules
  """

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
  Returns Stream of all Modules located in Project

  ## Exampes

      iex> Project.modules |> Enum.to_list
      [MyApp.Router, MyApp.Views, MyApp.I18n, ...]

  """
  def modules do
    Mix.Project.compile_path <> "**/*"
    |> Path.wildcard
    |> Stream.map(&(Path.basename(&1)))
    |> Stream.filter(&String.ends_with?(&1, ".beam"))
    |> Stream.map(&Path.basename(&1, ".beam"))
    |> Stream.map(&Module.concat([&1]))
  end
end
