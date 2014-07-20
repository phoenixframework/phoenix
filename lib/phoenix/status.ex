defmodule Phoenix.Status do

  @moduledoc """
  Conversion for transforming atoms to http status codes.
  """

  defmodule InvalidStatus do
    defexception [:message]

    def exception(value) do
      %InvalidStatus{message: "Invalid HTTP status #{inspect value}"}
    end
  end

  for line <- File.stream!(Path.join([__DIR__, "statuses.txt"]), [], :line) do
    [code, message] = line |> String.split("\t") |> Enum.map(&String.strip(&1))
    code = String.to_integer code
    atom = message
           |> String.downcase
           |> String.replace(~r/[^\w]+/, "_")
           |> String.to_atom

    def code(unquote(atom)), do: unquote(code)
  end

  @doc """
  Convert atom to http status code.

  When passed an integer status code, simply returns it, valid or not.

  ## Examples

      iex> Status.code(:ok)
      200

      iex> Status.code(200)
      200

  """
  def code(code) when is_integer(code), do: code
  def code(atom), do: raise(InvalidStatus, atom)
end
