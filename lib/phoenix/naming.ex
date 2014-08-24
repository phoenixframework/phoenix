defmodule Phoenix.Naming do
  use Inflex

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

end
