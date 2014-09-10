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
  Extracts the resource name from an alias.
  """
  def resource_name(alias, suffix \\ nil) do
    alias
    |> Module.split()
    |> List.last()
    |> remove_suffix(suffix)
    |> Phoenix.Naming.underscore()
  end

  defp remove_suffix(alias, nil),
    do: alias
  defp remove_suffix(alias, suffix) do
    suffix_size = byte_size(suffix)
    prefix_size = byte_size(alias) - suffix_size
    case alias do
      <<prefix::binary-size(prefix_size), ^suffix::binary>> -> prefix
      _ -> alias
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
