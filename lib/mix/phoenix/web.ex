defmodule Mix.Phoenix.Web do
  @moduledoc false

  alias Mix.Phoenix.{Schema, Attribute}

  @doc """
  Returns table columns for live index page, based on attributes.
  For array attribute adds `array_values(...)` wrapper to render values in basic manner.
  """
  def live_table_columns(%Schema{} = schema) do
    schema_singular = schema.singular

    schema.attrs
    |> Enum.map(fn attr ->
      value_expression = maybe_array_values(attr, "#{schema_singular}.#{attr.name}")

      ~s(<:col :let={{_id, #{schema_singular}}} label="#{label(attr.name)}"><%= #{value_expression} %></:col>)
    end)
    |> Mix.Phoenix.indent_text(spaces: 6, top: 1)
  end

  @doc """
  Returns table columns for html index page, based on attributes.
  For array attribute adds `array_values(...)` wrapper to render values in basic manner.
  """
  def table_columns(%Schema{} = schema) do
    schema_singular = schema.singular

    schema.attrs
    |> Enum.map(fn attr ->
      value_expression = maybe_array_values(attr, "#{schema_singular}.#{attr.name}")

      ~s(<:col :let={#{schema_singular}} label="#{label(attr.name)}"><%= #{value_expression} %></:col>)
    end)
    |> Mix.Phoenix.indent_text(spaces: 2, top: 1)
  end

  @doc """
  Returns list items for html and live show pages, based on attributes.
  For array attribute adds `array_values(...)` wrapper to render values in basic manner.
  """
  def list_items(%Schema{} = schema) do
    schema_singular = schema.singular

    schema.attrs
    |> Enum.map(fn attr ->
      value_expression = maybe_array_values(attr, "@#{schema_singular}.#{attr.name}")
      ~s(<:item title="#{label(attr.name)}"><%= #{value_expression} %></:item>)
    end)
  end

  defp maybe_array_values(%Attribute{type: {:array, _}}, value), do: "array_values(#{value})"
  defp maybe_array_values(_, value), do: value

  @doc """
  Returns implementation of `array_values(...)` wrapper to render values in basic manner,
  if there is an array attribute.
  """
  def maybe_def_array_values(%Schema{} = schema, privacy \\ :defp)
      when privacy in [:def, :defp] do
    if Enum.any?(schema.attrs, &(is_tuple(&1.type) and elem(&1.type, 0) == :array)) do
      ~s/#{privacy} array_values(values), do: (values || []) |> List.flatten() |> Enum.join(", ")/
      |> Mix.Phoenix.indent_text(spaces: 2, top: 2)
    end
  end

  @doc """
  Returns form inputs for html and live, based on attributes.
  Takes into account types and options of attributes.
  """
  def form_inputs(%Schema{} = schema, form) do
    schema.attrs
    |> Enum.reject(&(&1.type == :map))
    |> Enum.map(
      &~s(<.input field={#{form}[:#{&1.name}]} label="#{label(&1.name)}"#{input_specifics(&1, schema)}#{required_mark(&1)} />)
    )
    |> Enum.map_join("\n", &String.trim_trailing/1)
  end

  defp label(name), do: name |> to_string() |> Phoenix.Naming.humanize()

  defp required_mark(%Attribute{options: options}),
    do: if(not Map.has_key?(options, :default) and options[:required], do: " required", else: "")

  defp input_specifics(%Attribute{type: :integer}, _schema), do: ~s( type="number")
  defp input_specifics(%Attribute{type: :float}, _schema), do: ~s( type="number" step="any")
  defp input_specifics(%Attribute{type: :decimal}, _schema), do: ~s( type="number" step="any")
  defp input_specifics(%Attribute{type: :boolean}, _schema), do: ~s( type="checkbox")
  defp input_specifics(%Attribute{type: :text}, _schema), do: ~s( type="textarea")
  defp input_specifics(%Attribute{type: :date}, _schema), do: ~s( type="date")
  defp input_specifics(%Attribute{type: :time}, _schema), do: ~s( type="time")
  defp input_specifics(%Attribute{type: :utc_datetime}, _schema), do: ~s( type="datetime-local")
  defp input_specifics(%Attribute{type: :naive_datetime}, _schema), do: ~s( type="datetime-local")

  # NOTE: This implements only case with one level array.
  #       For nested arrays some grouping logic is needed, or new input creation on user action.
  defp input_specifics(%Attribute{type: {:array, _type}} = attr, schema),
    do: ~s( type="select" options={#{array_example_options(attr, schema)}} multiple)

  defp input_specifics(%Attribute{type: :enum} = attr, schema),
    do: ~s( type="select" options={#{enum_options(attr, schema)}} prompt="Choose a value")

  defp input_specifics(%Attribute{}, _schema), do: ~s( type="text")

  defp enum_options(attr, schema),
    do: "Ecto.Enum.values(#{inspect(schema.module)}, :#{attr.name})"

  defp array_example_options(%Attribute{type: {:array, :enum}} = attr, schema),
    do: enum_options(attr, schema)

  defp array_example_options(%Attribute{type: {:array, _}} = attr, schema) do
    (array_example_option(attr, schema, :create) ++ array_example_option(attr, schema, :update))
    |> inspect()
  end

  defp array_example_option(target_attr, schema, action) when action in [:create, :update] do
    schema.sample_values
    |> Map.fetch!(action)
    |> Enum.find_value(fn {attr, value} -> if attr == target_attr, do: value end)
  end
end
