defmodule Phoenix.HTML.Element do
  # FIXME not yet supported
  @tag_prefixes ~w(aria data)

  @boolean_attributes ~w(disabled readonly multiple checked autobuffer
    autoplay controls loop selected hidden scoped async
    defer reversed ismap seamless muted required
    autofocus novalidate formnovalidate open pubdate
    itemscope allowfullscreen default inert sortable
    truespeed typemustmatch)

  def element(name, [do: _] = clauses) do
    element(name, [], clauses)
  end

  def element(name, attributes \\ [], clauses \\ nil)

  def element(name, attributes, nil) do
    element(name, attributes, do: "")
  end

  def element(name, attributes, [do: do_clause]) do
    attribute_strings = attributes |> tag_attributes

    Phoenix.HTML.safe("<#{Enum.join([name | attribute_strings], " ")}>")
    |> Phoenix.HTML.safe_concat(do_clause)
    |> Phoenix.HTML.safe_concat(Phoenix.HTML.safe("</#{name}>"))
  end

  defp tag_attributes(attributes, acc \\ [])

  defp tag_attributes([], acc) do
    acc
  end

  defp tag_attributes([{key, value} | tail], acc) when is_atom(key) do
    tag_attributes([{to_string(key), value} | tail], acc)
  end

  defp tag_attributes([{_key, nil} |tail], acc) do
    tag_attributes(tail, acc)
  end

  defp tag_attributes([{key, value} | tail], acc) when key in @boolean_attributes and value == nil do
    tag_attributes(tail, acc)
  end

  defp tag_attributes([{key, _value} | tail], acc) when key in @boolean_attributes do
    tag_attributes(tail, [tag_option(key, key) | acc])
  end

  # FIXME support for @tag_prefixes here

  defp tag_attributes([{key, value} | tail], acc) do
    tag_attributes(tail, [tag_option(key, value) | acc])
  end

  defp tag_option(key, value) when is_list(value) do
    tag_option key, Enum.join(value, " ")
  end

  defp tag_option(key, value) do
    value = Phoenix.HTML.Safe.BitString.to_iodata(to_string(value))
    "#{key}=\"#{value}\""
  end
end
