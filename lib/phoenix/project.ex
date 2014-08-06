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
end
