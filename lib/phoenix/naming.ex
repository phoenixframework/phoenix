defmodule Phoenix.Naming do

  @doc """
  Converts String to underscore case

  ## Examples

      iex> Naming.underscore("MyApp")
      "my_app"

      iex> Naming.underscore("my-app")
      "my_app"

  """
  def underscore(string), do: do_underscore(String.codepoints(string), [])
  def do_underscore([], acc), do: acc |> Enum.reverse |> Enum.join("")
  def do_underscore([char | rest], []) when char in "A".."Z" do
    do_underscore(rest, [String.downcase(char)])
  end
  def do_underscore([char | rest], acc) when char in "A".."Z" do
    do_underscore(rest, [String.downcase(char), "_" | acc])
  end
  def do_underscore([char | rest], acc) when char in ["-"] do
    do_underscore(rest, ["_" | acc])
  end
  def do_underscore([char | rest], acc) do
    do_underscore(rest, [char | acc])
  end


  @doc """
  Converts String to camel case

  ## Examples

      iex> Naming.camelize("my_app")
      "MyApp"

      iex> Naming.camelize("my-app")
      "MyApp"

  """
  def camelize(string), do: do_camelize(String.codepoints(string), [])
  def do_camelize([], acc), do: acc |> Enum.reverse |> Enum.join("")
  def do_camelize([char | rest], []) when char in "a".."z" do
    do_camelize(rest, [String.upcase(char)])
  end
  def do_camelize([sep, next | rest], acc) when sep in ["_", "-"] do
    do_camelize(rest, [String.upcase(next) | acc])
  end
  def do_camelize([char | rest], acc) do
    do_camelize(rest, [char | acc])
  end

end
