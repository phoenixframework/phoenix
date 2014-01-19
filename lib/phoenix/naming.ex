defmodule Phoenix.Naming do

  @moduledoc """
  Module for handling Naming Conversions for use in param parsing and
  Route dispatching
  """

  @doc """
  Converts the String name from snake case to camel case

  Examples

    iex> Naming.snake_to_camel_case("users_controller")
    "UsersController"

  """
  def snake_to_camel_case(name) do
    Regex.split(%r/(?:^|[-_])(\w)/, to_string(name)) |> Enum.map_join(fn
      char when byte_size(char) == 1 -> String.upcase(char)
      part -> part
    end)
  end
end
