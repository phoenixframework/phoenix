defmodule Phoenix.View.Helpers.FormBuilder do

  @derive [Access]
  defstruct resource: nil, opts: []

  import Phoenix.View.Helpers.TagHelper

  alias Phoenix.View.Helpers.FormBuilder

  def form_for(resource, opts \\ [], func) do
    opts = Dict.put_new(opts, :method, :post)
    builder = %FormBuilder{resource: resource, opts: opts}
    form_tag(builder, opts, do: func.(builder))
  end

  def form_tag(builder, opts \\ [], [do: block]) do
    content_tag(:form, opts, do: block)
  end

  def text_field(builder, name, opts \\ []) do
    defaults = [type: "text", value: input_value(builder, name, opts)]
    attrs = Dict.merge([name: input_name(builder, name)], defaults)
    tag(:input, attrs)
  end

  defp input_name(builder, name) do
    builder.resource.__struct__
    |> Module.split
    |> List.last
    |> Phoenix.Naming.underscore
    |> Kernel.<> "[#{name}]"
  end

  defp input_value(builder, name, opts) do
    Dict.get(opts, :value) || get_in(builder, [:resource, name])
  end
end

