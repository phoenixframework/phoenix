defmodule Phoenix.Naming do
  @moduledoc """
  Conveniences for inflecting and working with names in Phoenix.
  """

  @doc """
  Extracts the resource name from an alias.

  ## Examples

      iex> Phoenix.Naming.resource_name(MyApp.User)
      "user"

      iex> Phoenix.Naming.resource_name(MyApp.UserView, "View")
      "user"

  """
  @spec resource_name(String.Chars.t, String.t) :: String.t
  def resource_name(alias, suffix \\ "") do
    alias
    |> to_string()
    |> Module.split()
    |> List.last()
    |> unsuffix(suffix)
    |> underscore()
  end

  @doc """
  Removes the given suffix from the name if it exists.

  ## Examples

      iex> Phoenix.Naming.unsuffix("MyApp.User", "View")
      "MyApp.User"

      iex> Phoenix.Naming.unsuffix("MyApp.UserView", "View")
      "MyApp.User"

  """
  @spec unsuffix(String.t, String.t) :: String.t
  def unsuffix(value, suffix) do
    string = to_string(value)
    suffix_size = byte_size(suffix)
    prefix_size = byte_size(string) - suffix_size
    case string do
      <<prefix::binary-size(prefix_size), ^suffix::binary>> -> prefix
      _ -> string
    end
  end

  @doc """
  Converts String to underscore case.

  ## Examples

      iex> Phoenix.Naming.underscore("MyApp")
      "my_app"

  In general, `underscore` can be thought of as the reverse of
  `camelize`, however, in some cases formatting may be lost:

      Phoenix.Naming.underscore "SAPExample"  #=> "sap_example"
      Phoenix.Naming.camelize   "sap_example" #=> "SapExample"

  """
  @spec underscore(String.t) :: String.t

  def underscore(""), do: ""

  def underscore(<<h, t :: binary>>) do
    <<to_lower_char(h)>> <> do_underscore(t, h)
  end

  defp do_underscore(<<h, t, rest :: binary>>, _) when h in ?A..?Z and not (t in ?A..?Z or t == ?.) do
    <<?_, to_lower_char(h), t>> <> do_underscore(rest, t)
  end

  defp do_underscore(<<h, t :: binary>>, prev) when h in ?A..?Z and not prev in ?A..?Z do
    <<?_, to_lower_char(h)>> <> do_underscore(t, h)
  end

  defp do_underscore(<<?., t :: binary>>, _) do
    <<?/>> <> underscore(t)
  end

  defp do_underscore(<<h, t :: binary>>, _) do
    <<to_lower_char(h)>> <> do_underscore(t, h)
  end

  defp do_underscore(<<>>, _) do
    <<>>
  end

  defp to_lower_char(char) when char in ?A..?Z, do: char + 32
  defp to_lower_char(char), do: char

  @doc """
  Converts String to camel case.

  Takes an optional `:lower` option to return lowerCamelCase.

  ## Examples

      iex> Phoenix.Naming.camelize("my_app")
      "MyApp"

      iex> Phoenix.Naming.camelize("my_app", :lower)
      "myApp"

  In general, `camelize` can be thought of as the reverse of
  `underscore`, however, in some cases formatting may be lost:

      Phoenix.Naming.underscore "SAPExample"  #=> "sap_example"
      Phoenix.Naming.camelize   "sap_example" #=> "SapExample"

  """
  @spec camelize(String.t) :: String.t
  def camelize(""), do: ""

  def camelize(<<?_, t :: binary>>) do
    camelize(t)
  end

  def camelize(<<h, t :: binary>>) do
    <<to_upper_char(h)>> <> do_camelize(t, :upper)
  end

  @spec camelize(String.t, :lower) :: String.t
  def camelize("", :lower), do: ""

  def camelize(<<?_, t :: binary>>, :lower) do
    camelize(t, :lower)
  end

  def camelize(<<h, t :: binary>>, :lower) do
    <<to_lower_char(h)>> <> do_camelize(t, :upper)
  end

  defp do_camelize(<<?_, ?_, t :: binary>>, atom) do
    do_camelize(<< ?_, t :: binary >>, atom)
  end

  defp do_camelize(<<?_, h, t :: binary>>, :lower) when h in ?A..?Z do
    <<to_lower_char(h)>> <> do_camelize(t, :upper)
  end

  defp do_camelize(<<?_, h, t :: binary>>, :upper) when h in ?a..?z do
    <<to_upper_char(h)>> <> do_camelize(t, :upper)
  end

  defp do_camelize(<<?_>>, _atom) do
    <<>>
  end

  defp do_camelize(<<?/, t :: binary>>, atom) do
    <<?.>> <> camelize(t, atom)
  end

  defp do_camelize(<<h, t :: binary>>, atom) do
    <<h>> <> do_camelize(t, atom)
  end

  defp do_camelize(<<>>, _atom) do
    <<>>
  end

  defp to_upper_char(char) when char in ?a..?z, do: char - 32
  defp to_upper_char(char), do: char

  @doc """
  Converts an attribute/form field into its humanize version.

      iex> Phoenix.Naming.humanize(:username)
      "Username"
      iex> Phoenix.Naming.humanize(:created_at)
      "Created at"
      iex> Phoenix.Naming.humanize("user_id")
      "User"
  """
  @spec humanize(atom | String.t) :: String.t
  def humanize(atom) when is_atom(atom),
    do: humanize(Atom.to_string(atom))
  def humanize(bin) when is_binary(bin) do
    bin =
      if String.ends_with?(bin, "_id") do
        binary_part(bin, 0, byte_size(bin) - 3)
      else
        bin
      end

    bin |> String.replace("_", " ") |> String.capitalize
  end
end
