defmodule Phoenix.HTML.Form do

  defstruct [
    resource: nil,
    input_prefix: "",
    opts: []
  ]

  import Phoenix.HTML.Tag

  alias Phoenix.HTML.Form

  def form_for(resource, opts \\ [], func) do
    opts = Dict.put_new(opts, :method, :post)
    builder = %Form{
      resource: resource,
      input_prefix: input_prefix(resource),
      opts: opts}
    form_tag(opts, do: func.(builder))
  end

  def form_tag(opts \\ [], [do: block]) do
    content_tag(:form, opts, do: block)
  end

  def text_field(builder, name, opts \\ []) do
    defaults = [type: "text", value: input_value(builder, name, opts)]
    attrs = defaults
      |> Keyword.put_new(:name, input_name(builder, name))
      |> Keyword.put_new(:id, dom_id(builder, name))
    input_tag(:text, attrs)
  end

  def label(builder, name) do
    label_text = name
      |> to_string()
      |> String.capitalize()
      |> String.replace("_", " ")
    label(builder, name, label_text)
  end
  def label(builder, name, label_text) do
    content_tag(:label, label_text, for: dom_id(builder, name))
  end

  defp input_prefix(resource) do
    resource.__struct__
    |> Module.split
    |> List.last
    |> Phoenix.Naming.underscore
  end

  defp dom_id(builder, name) do
    builder.input_prefix <> "_#{name}"
  end

  defp input_name(builder, name) do
    builder.input_prefix <> "[#{name}]"
  end

  defp input_value(builder, name, opts) do
    Dict.get(opts, :value, Map.get(builder.resource, name))
  end
end

