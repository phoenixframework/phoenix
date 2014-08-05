defmodule Phoenix.Project do

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
    |> Mix.Utils.camelize
    |> String.to_atom
  end
end
