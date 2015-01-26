defmodule Phoenix.HTML.Tag do
  @moduledoc ~S"""
  Helpers related to producing HTML tags within templates.
  """

  alias Phoenix.HTML.Safe

  @doc ~S"""
  Creates an HTML tag with the given name and options.

      iex> tag(:br)
      "<br>"
      iex> tag(:input, type: "text", name: "user_id")
      "<input name=\"user_id\" type=\"text\">"
  """
  def tag(name), do: tag(name, [])
  def tag(name, attrs) when is_list(attrs) do
    "<#{name}#{build_attrs(name, attrs)}>"
  end

  @doc """
  Creates an HTML tag with given name, content, and attributes.
  """
  def content_tag(name, content) when is_binary(content), do: content_tag(name, content, [])
  def content_tag(name, content, attrs) when is_binary(content) do
    content_tag(name, attrs, [do: content])
  end
  def content_tag(name, attrs, [do: block]) when is_list(attrs) do
    tag(name, attrs) <> block <> "</#{name}>"
  end

  @doc ~S"""
  Creates an HTML input field with the given type and options.

      iex> input_tag(:text, name: "name")
      "<input name=\"name\" type=\"text\">"
  """
  def input_tag(type, opts \\ []) do
    tag(:input, Keyword.put_new(opts, :type, type))
  end

  defp tag_attrs([]), do: ""
  defp tag_attrs(attrs) do
    Enum.map_join attrs, fn {k,v} ->
      " " <> k <> "=" <> "\"" <> Safe.to_iodata(v) <> "\""
    end
  end

  defp nested_attrs(attr, dict, acc) do
    Enum.reduce dict, acc, fn {k,v}, acc ->
      attr_name = "#{attr}-#{dasherize(k)}"
      case is_list(v) do
        true  -> nested_attrs(attr_name, v, acc)
        false -> [{attr_name, v}|acc]
      end
    end
  end

  defp build_attrs(_tag, []), do: []
  defp build_attrs(tag, attrs), do: build_attrs(tag, attrs, [])

  defp build_attrs(_tag, [], acc),
    do: acc |> Enum.sort |> tag_attrs
  defp build_attrs(tag, [{k,v}|t], acc) when is_list(v),
    do: build_attrs(tag, t, nested_attrs(k, v, acc))
  defp build_attrs(tag, [{k,v}|t], acc) when v == true,
    do: build_attrs(tag, t, [{to_string(k),k}|acc])
  defp build_attrs(tag, [{k,v}|t], acc),
    do: build_attrs(tag, t, [{to_string(k),v}|acc])

  defp dasherize(value) when is_atom(value), do: dasherize(Atom.to_string(value))
  defp dasherize(value), do: String.replace(value, "_", "-")
end
