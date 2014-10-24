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
    attrs = Dict.merge([name: input_name(builder, name)], defaults)
    tag(:input, attrs)
  end

  defp input_prefix(resource) do
    resource.__struct__
    |> Module.split
    |> List.last
    |> Phoenix.Naming.underscore
  end

  defp input_name(builder, name) do
    builder.input_prefix <> "[#{name}]"
  end

  defp input_value(builder, name, opts) do
    Dict.get(opts, :value, Map.get(builder.resource, name))
  end
end

