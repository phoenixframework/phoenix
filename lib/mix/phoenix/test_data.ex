defmodule Mix.Phoenix.TestData do
  @moduledoc false

  alias Mix.Phoenix.{Schema, Attribute}

  @doc """
  Clears virtual fields logic to be used in context test file.
  """
  def virtual_clearance(%Schema{} = schema) do
    schema_singular = schema.singular

    cleared_virtual =
      schema.attrs
      |> Attribute.virtual()
      |> Attribute.sort()
      |> Enum.map_join(", ", &"#{&1.name}: #{Schema.field_value(&1.options[:default], &1)}")

    if cleared_virtual != "" do
      ("# NOTE: Virtual fields updated to defaults or nil before comparison.\n" <>
         "#{schema_singular} = %{#{schema_singular} | #{cleared_virtual}}")
      |> Mix.Phoenix.indent_text(spaces: 6, top: 1)
    end
  end

  @doc """
  Map of data to be used in a fixture file.
  """
  def fixture(%Schema{} = schema) do
    unique_functions = fixture_unique_functions(schema.attrs, schema.singular)

    %{
      unique_functions: unique_functions,
      attrs: fixture_attrs(schema, unique_functions)
    }
  end

  defp fixture_unique_functions(schema_attrs, schema_singular) do
    schema_attrs
    |> Attribute.unique()
    |> Attribute.without_references()
    |> Attribute.sort()
    |> Enum.into(%{}, fn attr ->
      function_name = "unique_#{schema_singular}_#{attr.name}"

      {function_def, needs_implementation?} =
        case attr.type do
          :integer ->
            function_def =
              """
                def #{function_name}, do: System.unique_integer([:positive])
              """

            {function_def, false}

          type when type in [:string, :text] ->
            function_def =
              """
                def #{function_name}, do: "\#{System.unique_integer([:positive])}#{attr.name} value"
              """

            {function_def, false}

          _ ->
            function_def =
              """
                def #{function_name} do
                  raise "implement the logic to generate a unique #{schema_singular} #{attr.name}"
                end
              """

            {function_def, true}
        end

      {attr.name, {function_name, function_def, needs_implementation?}}
    end)
  end

  defp fixture_attrs(schema, unique_functions) do
    schema.sample_values.create
    |> Enum.map(fn {attr, value} ->
      value = fixture_attr_value(value, attr, unique_functions)
      "#{attr.name}: #{value}"
    end)
    |> Mix.Phoenix.indent_text(spaces: 8, top: 1, new_line: ",\n")
  end

  # NOTE: For references we create new fixture, which is unique.
  defp fixture_attr_value(value, %Attribute{type: :references}, _), do: value

  defp fixture_attr_value(_, %Attribute{options: %{unique: true}} = attr, unique_functions) do
    {function_name, _, _} = Map.fetch!(unique_functions, attr.name)
    "#{function_name}()"
  end

  defp fixture_attr_value(value, %Attribute{} = attr, _),
    do: Map.get(attr.options, :default, value) |> inspect()

  @doc """
  Invalid attributes used in live.
  """
  def live_invalid_attrs(%Schema{} = schema) do
    schema.sample_values.create
    |> Enum.map(fn {attr, value} ->
      value = value |> live_attr_value() |> live_invalid_attr_value() |> inspect()
      "#{attr.name}: #{value}"
    end)
    |> Mix.Phoenix.indent_text(spaces: 4, top: 1, new_line: ",\n")
  end

  defp live_invalid_attr_value(value) when is_list(value), do: []
  defp live_invalid_attr_value(true), do: false
  defp live_invalid_attr_value(_value), do: nil

  @doc """
  Returns message for live assertion in case of invalid attributes.
  """
  def live_required_attr_message, do: "can&#39;t be blank"

  @doc """
  Attributes with references used for `action` in live.
  """
  def live_action_attrs_with_references(%Schema{} = schema, action)
      when action in [:create, :update] do
    references_and_attrs =
      Mix.Phoenix.indent_text(schema.sample_values.references_assigns, bottom: 2) <>
        "#{action}_attrs = %{" <>
        Mix.Phoenix.indent_text(
          live_action_attrs(schema, action),
          spaces: 2,
          top: 1,
          bottom: 1,
          new_line: ",\n"
        ) <> "}"

    Mix.Phoenix.indent_text(references_and_attrs, spaces: 6)
  end

  defp live_action_attrs(%Schema{} = schema, action) when action in [:create, :update] do
    schema.sample_values
    |> Map.fetch!(action)
    |> Enum.map(fn {attr, value} ->
      value = value |> live_attr_value() |> format_attr_value(attr.type)
      "#{attr.name}: #{value}"
    end)
  end

  defp live_attr_value(%Date{} = date), do: Calendar.strftime(date, "%Y-%m-%d")
  defp live_attr_value(%Time{} = time), do: Calendar.strftime(time, "%H:%M")
  defp live_attr_value(%NaiveDateTime{} = naive), do: NaiveDateTime.to_iso8601(naive)
  defp live_attr_value(%DateTime{} = naive), do: DateTime.to_iso8601(naive)
  defp live_attr_value(value), do: value

  @doc """
  Attributes with references used for `action` in context, html, json.
  """
  def action_attrs_with_references(%Schema{} = schema, action)
      when action in [:create, :update] do
    references_and_attrs =
      Mix.Phoenix.indent_text(schema.sample_values.references_assigns, bottom: 2) <>
        "#{action}_attrs = %{" <>
        Mix.Phoenix.indent_text(
          action_attrs(schema, action),
          spaces: 2,
          top: 1,
          bottom: 1,
          new_line: ",\n"
        ) <> "}"

    Mix.Phoenix.indent_text(references_and_attrs, spaces: 6)
  end

  defp action_attrs(%Schema{} = schema, action) when action in [:create, :update] do
    schema.sample_values
    |> Map.fetch!(action)
    |> Enum.map(fn {attr, value} ->
      value = value |> format_attr_value(attr.type)
      "#{attr.name}: #{value}"
    end)
  end

  defp format_attr_value(value, :references), do: value
  defp format_attr_value(value, _type), do: inspect(value)

  @doc """
  Values assertions used for `action` in json.
  """
  def json_values_assertions(%Schema{} = schema, action) when action in [:create, :update] do
    json_values =
      schema.sample_values
      |> Map.fetch!(action)
      |> Enum.map(fn {attr, value} ->
        ~s("#{attr.name}" => #{json_assertion_value(attr, value)})
      end)

    [~s("id" => ^id) | json_values]
    |> Mix.Phoenix.indent_text(spaces: 15, new_line: ",\n")
  end

  defp json_assertion_value(%Attribute{type: :references} = attr, _value),
    do: json_references_value_assign(attr)

  defp json_assertion_value(attr, value) do
    if(attr.options[:virtual], do: attr.options[:default], else: value)
    |> Phoenix.json_library().encode!()
    |> Phoenix.json_library().decode!()
    |> inspect()
  end

  defp json_references_value_assign(%Attribute{name: name}), do: "json_#{name}"

  @doc """
  Values assertions used for references in json.
  """
  def json_references_values_assertions(%Schema{} = schema) do
    schema.attrs
    |> Attribute.references()
    |> Enum.map(&"assert #{json_references_value_assign(&1)} == #{references_value(&1)}")
    |> Mix.Phoenix.indent_text(spaces: 6, top: 2)
  end

  @doc """
  Returns data to use in html assertions, if there is a suitable field.
  """
  def html_assertion_field(%Schema{} = schema) do
    if html_assertion_attr = html_assertion_attr(schema.attrs) do
      %{
        name: html_assertion_attr.name,
        create_value: html_assertion_attr_value(html_assertion_attr, schema.sample_values.create),
        update_value: html_assertion_attr_value(html_assertion_attr, schema.sample_values.update)
      }
    end
  end

  # NOTE: For now we use only string field.
  #       Though current logic likely adjusted to other types as well, even `:references`.
  #       So, we can consider to use other types in cases with no string attributes.
  defp html_assertion_attr(attrs), do: Enum.find(attrs, &(&1.type in [:string, :text]))

  defp html_assertion_attr_value(%Attribute{} = html_assertion_attr, sample_values) do
    sample_values
    |> Enum.find_value(fn {attr, value} -> if attr == html_assertion_attr, do: value end)
    |> format_attr_value(html_assertion_attr.type)
  end

  @doc """
  Values assertions used for `action` in context.
  """
  def context_values_assertions(%Schema{} = schema, action) when action in [:create, :update] do
    schema_singular = schema.singular

    schema.sample_values
    |> Map.fetch!(action)
    |> Enum.map(fn {attr, value} ->
      "assert #{schema_singular}.#{attr.name} == #{context_assertion_value(value, attr)}"
    end)
    |> Mix.Phoenix.indent_text(spaces: 6)
  end

  defp context_assertion_value(value, %Attribute{type: :references}), do: value
  defp context_assertion_value(value, %Attribute{} = attr), do: Schema.field_value(value, attr)

  @doc """
  Map of base sample attrs to be used in test files.
  Specific formatting logic is invoked per case when it needed only (based on these data).
  """
  def sample_values(attrs, schema_module) do
    attrs = Attribute.sort(attrs)

    %{
      invalid: invalid_attrs(attrs),
      create: sample_action_attrs(attrs, :create),
      update: sample_action_attrs(attrs, :update),
      references_assigns: references_assigns(attrs, schema_module)
    }
  end

  defp invalid_attrs(attrs), do: Enum.map_join(attrs, ", ", &"#{&1.name}: nil")

  defp sample_action_attrs(attrs, action) when action in [:create, :update],
    do: Enum.map(attrs, &{&1, sample_attr_value(&1, action)})

  defp sample_attr_value(%Attribute{} = attr, :create) do
    case attr.type do
      :references -> references_value(attr)
      {:array, type} -> [sample_attr_value(%{attr | type: type}, :create)]
      :enum -> enum_value(attr.options.values, :create)
      :integer -> 142
      :float -> 120.5
      :decimal -> Attribute.adjust_decimal_value("22.5", attr.options)
      :boolean -> true
      :map -> %{}
      :uuid -> "7488a646-e31f-11e4-aace-600308960662"
      :date -> date_value(:create)
      :time -> ~T[14:00:00]
      :time_usec -> ~T[14:00:00.000000]
      :utc_datetime -> utc_datetime_value(:create)
      :utc_datetime_usec -> utc_datetime_usec_value(:create)
      :naive_datetime -> utc_naive_datetime_value(:create)
      :naive_datetime_usec -> utc_naive_datetime_usec_value(:create)
      _ -> maybe_apply_limit("#{attr.name} value", attr)
    end
  end

  defp sample_attr_value(%Attribute{} = attr, :update) do
    case attr.type do
      :references -> references_value(attr)
      {:array, type} -> [sample_attr_value(%{attr | type: type}, :update)]
      :enum -> enum_value(attr.options.values, :update)
      :integer -> 303
      :float -> 456.7
      :decimal -> Attribute.adjust_decimal_value("18.7", attr.options)
      :boolean -> false
      :map -> %{}
      :uuid -> "7488a646-e31f-11e4-aace-600308960668"
      :date -> date_value(:update)
      :time -> ~T[15:01:01]
      :time_usec -> ~T[15:01:01.000000]
      :utc_datetime -> utc_datetime_value(:update)
      :utc_datetime_usec -> utc_datetime_usec_value(:update)
      :naive_datetime -> utc_naive_datetime_value(:update)
      :naive_datetime_usec -> utc_naive_datetime_usec_value(:update)
      _ -> maybe_apply_limit("updated #{attr.name} value", attr)
    end
  end

  defp maybe_apply_limit(value, attr) do
    if size = attr.options[:size] do
      String.slice(value, 0, size)
    else
      value
    end
  end

  defp enum_value([{_, _} | _] = values, action), do: enum_value(Keyword.keys(values), action)
  defp enum_value([first | _], :create), do: first
  defp enum_value([first | rest], :update), do: List.first(rest) || first

  defp date_value(:create), do: Date.add(date_value(:update), -1)
  defp date_value(:update), do: Date.utc_today()

  @one_day_in_seconds 24 * 3600

  defp utc_datetime_value(:create) do
    DateTime.add(
      utc_datetime_value(:update),
      -@one_day_in_seconds,
      :second,
      Calendar.UTCOnlyTimeZoneDatabase
    )
  end

  defp utc_datetime_value(:update),
    do: DateTime.truncate(utc_datetime_usec_value(:update), :second)

  defp utc_datetime_usec_value(:create) do
    DateTime.add(
      utc_datetime_usec_value(:update),
      -@one_day_in_seconds,
      :second,
      Calendar.UTCOnlyTimeZoneDatabase
    )
  end

  defp utc_datetime_usec_value(:update),
    do: %{DateTime.utc_now() | second: 0, microsecond: {0, 6}}

  defp utc_naive_datetime_value(:create),
    do: NaiveDateTime.add(utc_naive_datetime_value(:update), -@one_day_in_seconds)

  defp utc_naive_datetime_value(:update),
    do: NaiveDateTime.truncate(utc_naive_datetime_usec_value(:update), :second)

  defp utc_naive_datetime_usec_value(:create),
    do: NaiveDateTime.add(utc_naive_datetime_usec_value(:update), -@one_day_in_seconds)

  defp utc_naive_datetime_usec_value(:update),
    do: %{NaiveDateTime.utc_now() | second: 0, microsecond: {0, 6}}

  defp references_assigns(attrs, schema_module) do
    attrs
    |> Attribute.references()
    |> Attribute.sort()
    |> Enum.map(&references_assign(&1, schema_module))
  end

  defp references_assign(%Attribute{} = attr, schema_module) do
    association_name = attr.options.association_name

    [referenced_schema_name | referenced_rest] =
      attr.options.association_schema |> Module.split() |> Enum.reverse()

    referenced_context = referenced_rest |> Enum.reverse() |> Module.concat() |> inspect()
    context = schema_module |> Module.split() |> Enum.drop(-1) |> Module.concat() |> inspect()
    fixtures_module = if referenced_context != context, do: "#{referenced_context}Fixtures."

    fixture_method = "#{Phoenix.Naming.underscore(referenced_schema_name)}_fixture()"

    "#{association_name} = #{fixtures_module}#{fixture_method}"
  end

  # NOTE: Based on `references_assign` part.
  defp references_value(%Attribute{} = attr),
    do: "#{attr.options.association_name}.#{attr.options.referenced_column}"
end
