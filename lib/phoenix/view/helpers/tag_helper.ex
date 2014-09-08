defmodule Phoenix.View.Helpers.TagHelper do
  @moduledoc ~S"""
  Helpers related to producing html tags within templates.
  """

  alias Phoenix.Html.Safe

  @data_attrs [:method, :remote, :confirm]

  @boolean_attrs [
    :autoplay,
    :autofocus,
    :formnovalidate,
    :checked,
    :disabled,
    :hidden,
    :loop,
    :multiple,
    :muted,
    :readonly,
    :required,
    :selected,
    :declare,
    :defer,
    :ismap,
    :itemscope,
    :noresize,
    :novalidate
  ]

  @doc ~S"""
  Creates an HTML tag with the given name and options.

  ## Examples
      iex> tag(:br)
      "<br>"
      iex> tag(:input, type: "text", name: "user_id")
      "<input name="user_id" type="text">"
  """
  def tag(name),                              do: tag(name, [], true)
  def tag(name, attrs) when is_list(attrs),   do: tag(name, attrs, true)
  def tag(name, open)  when is_boolean(open), do: tag(name, [], open)
  def tag(name, attrs, open) do
    attrs = build_attributes(name, attrs) |> List.flatten |> Enum.sort
    "<#{name}#{tag_attributes(attrs)}#{if open, do: ">", else: " />"}"
  end

  @doc ~S"""
  Creates an HTML tag with given name, content, and attributes.
  """
  def content_tag(name, content) when is_binary(content), do: content_tag(name, content, [])
  def content_tag(name, content, attrs) when is_binary(content) do
    content_tag(name, attrs, [do: content])
  end
  def content_tag(name, attrs, [do: block]) when is_list(attrs) do
    tag(name, attrs) <> block <> "</#{name}>"
  end

  @doc false
  defp tag_attributes([]), do: ""
  defp tag_attributes(attrs) do
    Enum.map_join attrs, fn {k,v} -> ~s( #{k}="#{Safe.to_string(v)}") end
  end

  @doc false
  defp nested_attrs(attr, dict) do
    Enum.map dict, fn {k,v} ->
      attr_name = :"#{attr}-#{dasherize(k)}"
      case is_list(v) do
        true  -> nested_attrs(attr_name, v)
        false -> {attr_name, v}
      end
    end
  end

  @doc false
  defp build_attrs(_tag, []), do: []
  defp build_attrs(tag, attrs), do: build_attrs(tag, attrs, [])

  defp build_attrs(_tag, [], acc),
    do: acc |> List.flatten |> Enum.sort |> tag_attrs
  defp build_attrs(:form, [{:method,v}|t], acc),
    do: build_attrs(:form, t, [{:method, v}|acc])
  defp build_attrs(tag, [{k,v}|t], acc) when is_list(v),
    do: build_attrs(tag, t, [[nested_attrs(k,v)]|acc])
  defp build_attrs(tag, [{k,v}|t], acc) when k in @data_attrs,
    do: build_attrs(tag, t, [[{:"data-#{k}", v}]|acc])
  defp build_attrs(tag, [{k,_v}|t], acc) when k in @boolean_attrs,
    do: build_attrs(tag, t, [{k,k}|acc])
  defp build_attrs(tag, [{:method,v}|t], acc),
    do: build_attrs(tag, t, [[{:"data-method", v}, {:rel, "nofollow"}]|acc])
  defp build_attrs(tag, [{k,v}|t], acc),
    do: build_attrs(tag, t, [[{k,v}]|acc])

  @doc false
  defp dasherize(value) when is_atom(value), do: dasherize(Atom.to_string(value))
  defp dasherize(value), do: String.replace(value, "_", "-")
end
