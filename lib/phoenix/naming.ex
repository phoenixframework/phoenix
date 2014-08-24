defmodule Phoenix.Naming do

  @doc """
  Returns the String name of the module, without leading `Elixir.` prefix

  ## Examples

      iex> Naming.module_name(Phoenix.Naming)
      "Phoenix.Naming"

      iex> Naming.module_name(:math)
      "math"

  """
  def module_name(module) do
    case to_string(module) do
      <<"Elixir." <> rest >> -> rest
      mod                    -> mod
    end
  end

  @doc """
  Converts String to underscore case

  ## Examples

      iex> Naming.underscore("MyApp")
      "my_app"

      iex> Naming.underscore("my-app")
      "my_app"

  """
  def underscore(string), do: Mix.Utils.underscore(string)

  @doc """
  Converts String to camel case

  ## Examples

      iex> Naming.camelize("my_app")
      "MyApp"

      iex> Naming.camelize("my-app")
      "MyApp"

  """
  def camelize(string) do
    Regex.replace(~r/-/, string, "_") |> Mix.Utils.camelize
  end
end
