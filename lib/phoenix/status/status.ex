defmodule Phoenix.Status do

  @moduledoc """
  Conversion for transforming atoms to http status codes.
  """
  for line <- File.stream!(Path.join([__DIR__, "status.txt"]), [], :line) do
    [code, message] = line |> String.split("\t") |> Enum.map(&String.strip(&1))
    code = String.to_integer code
    atom = message
            |> String.downcase
            |> String.replace(~r/[^\w]+/, "_")
            |> String.to_atom

    def code(unquote(atom)), do: unquote(code)
  end

  @doc """
  Convert atom to http status code

  Examples
  iex> Status.code(:ok)
  200
  """
  def code(_atom), do: nil

end
