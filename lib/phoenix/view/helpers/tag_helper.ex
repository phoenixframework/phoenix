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
  Creates an HTML tag with given name, content, and options.
  """
  def content_tag(name, content) when is_binary(content), do: content_tag(name, content, [])
  def content_tag(name, content, attrs) when is_binary(content) do
    content_tag(name, attrs, [do: content])
  end
  def content_tag(name, attrs \\ [], [do: block]) do
    tag(name, attrs) <> block <> "</#{name}>"
  end

  @doc false
  defp tag_attributes([]), do: ""
  defp tag_attributes(attrs) do
    Enum.map_join attrs, fn {k,v} -> ~s( #{k}="#{Safe.to_string(v)}") end
  end

  @doc false
  defp nested_attributes(attr, dict) do
    Enum.map dict, fn {k,v} ->
      attr_name = :"#{attr}-#{dasherize(k)}"
      case is_list(v) do
        true  -> nested_attributes(attr_name, v)
        false -> {attr_name, v}
      end
    end
  end

  @doc false
  defp build_attributes(tag, []), do: []
  defp build_attributes(tag, attrs) do
    Enum.map attrs, fn {k,v} ->
      cond do
        k in @boolean_attrs -> {k, k}
        is_list(v) -> nested_attributes(k, v)
        not k in @data_attrs || (tag == :form && k == :method) -> {k, v}
        k == :method -> [{:"data-#{k}", v}, {:rel, "nofollow"}]
        true -> {:"data-#{k}", v}
      end
    end
  end

  @doc false
  defp dasherize(value) when is_atom(value), do: dasherize(Atom.to_string(value))
  defp dasherize(value), do: String.replace(value, "_", "-")
end
