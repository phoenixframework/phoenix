defmodule Mix.Phoenix.Attribute do
  @moduledoc false

  alias Mix.Phoenix.{Attribute, Schema}

  defstruct name: nil,
            type: nil,
            options: %{}

  @default_type :string
  @standard_types_specs %{
    "integer" => %{
      options: ["default,value"],
      details: "",
      examples: [
        "points:integer",
        "points:integer:default,0"
      ]
    },
    "float" => %{
      options: ["default,value"],
      details: "",
      examples: [
        "sum:float",
        "sum:float:default,0.0"
      ]
    },
    "decimal" => %{
      options: ["default,value", "precision,value", "scale,value"],
      details: "Have specific options `precision` and `scale`.",
      examples: [
        "price:decimal",
        "price:decimal:precision,5:scale,2",
        "price:decimal:precision,5",
        "price:decimal:default,0.0"
      ]
    },
    "boolean" => %{
      options: ["default,value"],
      details: "Default to `false`, which can be changed with option.",
      examples: [
        "agreed:boolean",
        "the_cake_is_a_lie:boolean:default,true"
      ]
    },
    "string" => %{
      options: ["size,value"],
      details:
        "Default type. Can be omitted if no options are provided. " <>
          "Use `size` option to limit number of characters.",
      examples: [
        "title",
        "title:string",
        "title:string:size,40:unique"
      ]
    },
    "text" => %{
      details: "",
      examples: []
    },
    "binary" => %{
      details: "",
      examples: []
    },
    "uuid" => %{
      details: "",
      examples: []
    },
    "date" => %{
      details: "",
      examples: []
    },
    "time" => %{
      details: "",
      examples: []
    },
    "time_usec" => %{
      details: "",
      examples: []
    },
    "naive_datetime" => %{
      details: "",
      examples: []
    },
    "naive_datetime_usec" => %{
      details: "",
      examples: []
    },
    "utc_datetime" => %{
      details: "",
      examples: []
    },
    "utc_datetime_usec" => %{
      details: "",
      examples: []
    },
    "map" => %{
      details: "",
      examples: []
    },
    "enum" => %{
      options: ["[one,two]", "[[one,1],[two,2]]"],
      details:
        "Requires at least one value in options. Values are translated into list or keyword list.",
      examples: [
        "status:enum:[published,unpublished]",
        "status:enum:[[published,1],[unpublished,2]]",
        "tags:[array,enum]:[published,unpublished]",
        "tags:[array,enum]:[[published,1],[unpublished,2]]"
      ]
    },
    "references" => %{
      options: [
        "Context.Schema",
        "table,value",
        "column,value",
        "type,value",
        "assoc,value",
        "on_delete,value"
      ],
      details:
        "All info is inferred from the attribute name unless customized via options. " <>
          "Referenced schema is inferred in scope of the given context. " <>
          "Different schema can be provided in full form `Context.Schema` in options. " <>
          "Referenced schema should exist in the app.",
      examples: [
        "post_id:references",
        "author_id:references:Accounts.User"
      ]
    },
    "any" => %{
      details: "Can be used only with option `virtual`.",
      examples: ["data:any:virtual"]
    }
  }
  @standard_types Map.keys(@standard_types_specs)
  @specific_types_specs %{
    "datetime" => %{
      details: "An alias for `naive_datetime`.",
      examples: []
    },
    "array" => %{
      details: "An alias for `[array,string]`.",
      examples: ["tags:array"]
    },
    "[array,inner_type]" => %{
      regex: ~r/^\[array,(?<inner_type>.+)\]$/,
      details: "Composite type, requires `inner_type`, which cannot be `references`.",
      examples: [
        "tags:[array,string]",
        "tags:[array,integer]",
        "tags:[array,enum]:[published,unpublished]",
        "tags:[array,enum]:[[published,1],[unpublished,2]]"
      ]
    }
  }
  @supported_types_specs Map.merge(@standard_types_specs, @specific_types_specs)

  @doc """
  List of supported attribute types with details and examples.
  """
  def supported_types do
    "### Supported attribute types#{format_specs(@supported_types_specs)}"
  end

  @precision_min 2
  @scale_min 1
  @supported_options_specs %{
    "unique" => %{
      details: "Adds unique index in migration and validation in schema.",
      examples: ["title:string:unique"]
    },
    "index" => %{
      details: "Adds index in migration.",
      examples: ["title:string:index"]
    },
    "redact" => %{
      details: "Adds option to schema field.",
      examples: ["card_number:string:redact"]
    },
    "required" => %{
      details:
        "Adds `null: false` constraint in migration, validation in schema, " <>
          "and mark in html input if no default option provided.",
      examples: ["title:string:required"]
    },
    "*" => %{
      details: "An alias for `required`.",
      examples: ["title:string:*"]
    },
    "virtual" => %{
      details:
        "Adds option to schema field and omits migration changes. Can be used with type `any`.",
      examples: [
        "current_guess:integer:virtual",
        "data:any:virtual"
      ]
    },
    "[one,two]" => %{
      regex: ~r/^\[(?<values>.+)\]$/,
      details: "List of values for `enum` type. At least one value is mandatory.",
      examples: ["status:enum:[published,unpublished]"]
    },
    "[[one,1],[two,2]]" => %{
      regex: ~r/^\[\[(?<values>.+)\]\]$/,
      details: "Keyword list of values for `enum` type. At least one value is mandatory.",
      examples: ["status:enum:[[published,1],[unpublished,2]]"]
    },
    "default,value" => %{
      regex: ~r/^default,(?<value>.+)$/,
      details:
        "Default option for `boolean`, `integer`, `decimal`, `float` types. " <>
          "For `boolean` type values `true`, `1` are the same, the rest is `false`.",
      examples: [
        "the_cake_is_a_lie:boolean:default,true",
        "points:integer:default,0",
        "price:decimal:default,0.0",
        "sum:float:default,0.0"
      ]
    },
    "size,value" => %{
      regex: ~r/^size,(?<value>\d+)$/,
      details: "Positive number option for `string` type.",
      examples: ["city:string:size,40"]
    },
    "precision,value" => %{
      regex: ~r/^precision,(?<value>\d+)$/,
      details: "Number option for `decimal` type. Minimum is #{@precision_min}.",
      examples: ["price:decimal:precision,5"]
    },
    "scale,value" => %{
      regex: ~r/^scale,(?<value>\d+)$/,
      details:
        "Number option for `decimal` type. Minimum is #{@scale_min}. " <>
          "`scale` can be provided only with `precision` option and should be less than it.",
      examples: ["price:decimal:precision,5:scale,2"]
    },
    "Context.Schema" => %{
      details:
        "Referenced schema name for `references`. " <>
          "For cases when schema cannot be inferred from the attribute name, or context differs.",
      examples: ["author_id:references:Accounts.User"]
    },
    "table,value" => %{
      regex: ~r/^table,(?<value>.+)$/,
      details:
        "Table name for `references`. " <>
          "For cases when referenced schema is not reachable to reflect on.",
      examples: ["booking_id:references:table,reservations"]
    },
    "column,value" => %{
      regex: ~r/^column,(?<value>.+)$/,
      details:
        "Referenced column name for `references`. " <>
          "For cases when it differs from default value `id`.",
      examples: ["book_id:references:column,isbn"]
    },
    "type,value" => %{
      regex: ~r/^type,(?<value>.+)$/,
      details:
        "Type of the column for `references`. " <>
          "For cases when referenced schema is not reachable to reflect on. " <>
          "Supported values: `id`, `binary_id`, `string`.",
      examples: [
        "book_id:references:type,id",
        "book_id:references:type,binary_id",
        "isbn:references:column,isbn:type,string"
      ]
    },
    "assoc,value" => %{
      regex: ~r/^assoc,(?<value>.+)$/,
      details:
        "Association name for `references`. " <>
          "For cases when it cannot be inferred from the attribute name. " <>
          "Default to attribute name without suffix `_id`.",
      examples: ["booking_id:references:assoc,reservation"]
    },
    "on_delete,value" => %{
      regex: ~r/^on_delete,(?<value>.+)$/,
      details:
        "What to do if the referenced entry is deleted. " <>
          "`value` may be `nothing` (default), `restrict`, `delete_all`, `nilify_all` or `nilify[columns]`. " <>
          "`nilify[columns]` expects a comma-separated list of columns and is not supported by all databases.",
      examples: [
        "author_id:references:on_delete,delete_all",
        "book_id:references:on_delete,nilify[book_id,book_name]"
      ]
    }
  }

  @doc """
  List of supported attribute options with details and examples.
  """
  def supported_options do
    "### Supported attribute options#{format_specs(@supported_options_specs)}"
  end

  defp format_specs(specs) do
    specs
    |> Enum.sort_by(fn {value, _info} -> value end)
    |> Enum.map(fn {value, %{details: details, examples: examples}} ->
      formatted_details = if details != "", do: " - #{details}"

      formatted_examples =
        if Enum.any?(examples) do
          "\n      Examples:#{Mix.Phoenix.indent_text(examples, spaces: 10, top: 2)}"
        end

      "* `#{value}`#{formatted_details}#{formatted_examples}"
    end)
    |> Enum.join("\n\n")
    |> Mix.Phoenix.indent_text(spaces: 2, top: 2, bottom: 1)
  end

  defp raise_unknown_type_error(type, cli_attr) do
    Mix.raise("""
    Unknown type `#{type}` is given in CLI attribute `#{cli_attr}`.

    #{supported_types()}
    """)
  end

  defp raise_unknown_option_error({option, type, cli_attr}) do
    Mix.raise("""
    Unknown option `#{option}` is given in CLI attribute `#{cli_attr}`.
    #{type_specs(type)}
    """)
  end

  defp raise_type_error(type, cli_attr) do
    Mix.raise("""
    CLI attribute `#{cli_attr}` has issue related to its type `#{type}`.
    #{type_specs(type)}
    """)
  end

  # THOUGHTS: Can also be used to print help info about type in console.
  @doc """
  List of supported options for the given attribute's type, with details.
  """
  def type_specs(type) do
    type_spec = Map.fetch!(@supported_types_specs, Atom.to_string(type))

    formatted_details =
      if type_spec[:details] != "", do: "\n`#{type}` - #{type_spec[:details]}\n\n"

    virtual_option = if type == :references, do: [], else: ["virtual"]
    general_options = ["unique", "index", "redact", "required", "*"] ++ virtual_option
    type_options = general_options ++ Map.get(type_spec, :options, [])
    type_options_specs = Map.take(@supported_options_specs, type_options)

    "#{formatted_details}`#{type}` supports following options.#{format_specs(type_options_specs)}"
  end

  @doc """
  General sorting for attributes - by name with references at the end.
  """
  def sort(attrs) when is_list(attrs), do: Enum.sort_by(attrs, &{&1.type == :references, &1.name})

  @doc """
  Excludes references from attributes.
  """
  def without_references(attrs) when is_list(attrs),
    do: Enum.reject(attrs, &(&1.type == :references))

  @doc """
  Returns only references from attributes.
  """
  def references(attrs) when is_list(attrs), do: Enum.filter(attrs, &(&1.type == :references))

  @doc """
  Excludes virtual attributes.
  """
  def without_virtual(attrs) when is_list(attrs), do: Enum.reject(attrs, & &1.options[:virtual])

  @doc """
  Returns only virtual attributes.
  """
  def virtual(attrs) when is_list(attrs), do: Enum.filter(attrs, & &1.options[:virtual])

  @doc """
  Returns required attributes.
  """
  def required(attrs) when is_list(attrs), do: Enum.filter(attrs, & &1.options[:required])

  @doc """
  Returns unique attributes.
  """
  def unique(attrs) when is_list(attrs), do: Enum.filter(attrs, & &1.options[:unique])

  @doc """
  Returns attributes which have index (unique or general).
  """
  def indexed(attrs) when is_list(attrs),
    do: Enum.filter(attrs, &(&1.options[:unique] || &1.options[:index]))

  @doc """
  Parses list of CLI attributes into %Attribute{} structs.
  Performs attributes' types and options validation.
  Prefills some mandatory and default data to options map.
  Checks that at least one attribute is required.
  """
  def parse([], _), do: []

  def parse(cli_attrs, schema_details) when is_list(cli_attrs) do
    attrs = Enum.map(cli_attrs, &parse_attr(&1, schema_details))

    if Enum.any?(attrs, & &1.options[:required]) do
      attrs
    else
      with_first_attr_required(attrs, hd(cli_attrs))
    end
  end

  defp with_first_attr_required(attrs, first_cli_attr) do
    Mix.shell().info("""
    At least one attribute has to be specified as required.
    Use option `required` or its alias `*`.

    Examples:

        title:string:required
        name:string:*:unique

    None of the given attributes are set to be required,
    Hence first attribute `#{first_cli_attr}` is going to be required.
    """)

    if not Mix.shell().yes?("Proceed with chosen required attribute?"), do: System.halt()

    [first | rest] = attrs
    required_first = %{first | options: Map.put(first.options, :required, true)}
    [required_first | rest]
  end

  defp parse_attr(cli_attr, schema_details) when is_binary(cli_attr) do
    cli_attr
    |> String.split(":")
    |> parse_name()
    |> parse_type(cli_attr)
    |> parse_options(cli_attr)
    |> validate_attr(cli_attr)
    |> prefill_data(schema_details)
    |> new()
  end

  defp new({name, type, %{} = options}) do
    %Attribute{
      name: name,
      type: type,
      options: options
    }
  end

  defp parse_name([name | rest]), do: {String.to_atom(name), rest}

  defp parse_type({name, []}, _cli_attr), do: {name, @default_type, %{}}
  defp parse_type({name, [type]}, cli_attr), do: {name, string_to_type(type, cli_attr), %{}}

  defp parse_type({name, [type | options]}, cli_attr),
    do: {name, string_to_type(type, cli_attr), options}

  defp string_to_type(type, _cli_attr) when type in @standard_types, do: String.to_atom(type)
  defp string_to_type("datetime", _cli_attr), do: :naive_datetime
  defp string_to_type("array", _cli_attr), do: {:array, :string}

  defp string_to_type(type, cli_attr) do
    cond do
      match = regex_match("[array,inner_type]", type, @specific_types_specs) ->
        if match["inner_type"] == "references", do: raise_unknown_type_error(type, cli_attr)
        {:array, string_to_type(match["inner_type"], cli_attr)}

      true ->
        raise_unknown_type_error(type, cli_attr)
    end
  end

  defp parse_options({name, type, options}, cli_attr) do
    options =
      Enum.reduce(options, %{}, fn option, parsed_options ->
        Map.merge(parsed_options, string_to_options({option, type, cli_attr}))
      end)

    {name, type, options}
  end

  defp string_to_options({"*", _, _}), do: %{required: true}

  defp string_to_options({"virtual", type, _}) when type not in [:references],
    do: %{virtual: true}

  @flag_options ["unique", "index", "redact", "required"]
  defp string_to_options({option, _, _}) when option in @flag_options,
    do: %{String.to_atom(option) => true}

  defp string_to_options({option, {:array, inner_type}, cli_attr}),
    do: string_to_options({option, inner_type, cli_attr})

  defp string_to_options({option, :enum, _} = data) do
    cond do
      match = regex_match("[[one,1],[two,2]]", option) ->
        parsed_values =
          match["values"]
          |> String.split("],[")
          |> Enum.map(fn value ->
            [value_name, value_int] = String.split(value, ",")
            {String.to_atom(value_name), String.to_integer(value_int)}
          end)

        %{values: parsed_values}

      match = regex_match("[one,two]", option) ->
        parsed_values = match["values"] |> String.split(",") |> Enum.map(&String.to_atom/1)
        %{values: parsed_values}

      true ->
        raise_unknown_option_error(data)
    end
  end

  defp string_to_options({option, :decimal, _} = data) do
    cond do
      match = regex_match("precision,value", option) ->
        %{precision: String.to_integer(match["value"])}

      match = regex_match("scale,value", option) ->
        %{scale: String.to_integer(match["value"])}

      match = regex_match("default,value", option) ->
        %{default: match["value"] |> String.to_float() |> Float.to_string()}

      true ->
        raise_unknown_option_error(data)
    end
  end

  defp string_to_options({option, :float, _} = data) do
    cond do
      match = regex_match("default,value", option) -> %{default: String.to_float(match["value"])}
      true -> raise_unknown_option_error(data)
    end
  end

  defp string_to_options({option, :integer, _} = data) do
    cond do
      match = regex_match("default,value", option) ->
        %{default: String.to_integer(match["value"])}

      true ->
        raise_unknown_option_error(data)
    end
  end

  defp string_to_options({option, :boolean, _} = data) do
    cond do
      match = regex_match("default,value", option) -> %{default: match["value"] in ["true", "1"]}
      true -> raise_unknown_option_error(data)
    end
  end

  defp string_to_options({option, :string, _} = data) do
    cond do
      match = regex_match("size,value", option) -> %{size: String.to_integer(match["value"])}
      true -> raise_unknown_option_error(data)
    end
  end

  defp string_to_options({option, :references, _} = data) do
    cond do
      match = regex_match("assoc,value", option) ->
        %{association_name: String.to_atom(match["value"])}

      match = regex_match("column,value", option) ->
        %{column: String.to_atom(match["value"])}

      match = regex_match("type,value", option) ->
        type = references_type(match["value"]) || raise_unknown_option_error(data)
        %{type: type}

      match = regex_match("on_delete,value", option) ->
        on_delete = references_on_delete(match["value"]) || raise_unknown_option_error(data)
        %{on_delete: on_delete}

      match = regex_match("table,value", option) ->
        %{table: match["value"]}

      Schema.valid?(option) ->
        %{referenced_schema: option}

      true ->
        raise_unknown_option_error(data)
    end
  end

  defp string_to_options({_, _, _} = data), do: raise_unknown_option_error(data)

  @referenced_types ["id", "binary_id", "string"]
  defp references_type(value), do: if(value in @referenced_types, do: String.to_atom(value))

  @references_on_delete_values ["nothing", "delete_all", "nilify_all", "restrict"]
  defp references_on_delete(value) when value in @references_on_delete_values,
    do: String.to_atom(value)

  defp references_on_delete(value) do
    if columns_match = Regex.named_captures(~r/^nilify\[(?<columns>.+)\]$/, value) do
      {:nilify, columns_match["columns"] |> String.split(",") |> Enum.map(&String.to_atom/1)}
    end
  end

  defp regex_match(spec_key, value, spec \\ @supported_options_specs),
    do: Regex.named_captures(spec[spec_key].regex, value)

  defp validate_attr({_name, :any, options} = attr, cli_attr) do
    cond do
      not Map.has_key?(options, :virtual) -> raise_type_error(:any, cli_attr)
      true -> attr
    end
  end

  defp validate_attr({_name, :string, options} = attr, cli_attr) do
    cond do
      Map.get(options, :size, 1) <= 0 -> raise_type_error(:string, cli_attr)
      true -> attr
    end
  end

  defp validate_attr({_name, :decimal, options} = attr, cli_attr) do
    cond do
      Map.has_key?(options, :scale) and not Map.has_key?(options, :precision) ->
        raise_type_error(:decimal, cli_attr)

      Map.get(options, :precision, @precision_min) <=
        (scale = Map.get(options, :scale, @scale_min)) or scale <= 0 ->
        raise_type_error(:decimal, cli_attr)

      true ->
        attr
    end
  end

  defp validate_attr({_name, :enum, options} = attr, cli_attr) do
    cond do
      not Map.has_key?(options, :values) -> raise_type_error(:enum, cli_attr)
      true -> attr
    end
  end

  defp validate_attr({name, {:array, inner_type}, options} = attr, cli_attr) do
    validate_attr({name, inner_type, options}, cli_attr)
    attr
  end

  defp validate_attr(attr, _cli_attr), do: attr

  defp prefill_data({name, :boolean, options}, _schema_details) do
    options =
      options
      |> Map.put(:required, true)
      |> Map.put_new(:default, false)

    {name, :boolean, options}
  end

  defp prefill_data({name, :decimal, options}, _schema_details) do
    options =
      options
      |> maybe_adjust_decimal_default()

    {name, :decimal, options}
  end

  defp prefill_data({name, :references, options}, schema_details) do
    options =
      options
      |> Map.put(:index, true)
      |> Map.put_new(:on_delete, :nothing)
      |> derive_association_name(name)
      |> derive_references_schema(name, schema_details)
      |> derive_references_table()
      |> derive_references_type()

    {name, :references, options}
  end

  defp prefill_data(attr, _schema_details), do: attr

  defp maybe_adjust_decimal_default(%{default: default} = options),
    do: Map.put(options, :default, adjust_decimal_value(default, options))

  defp maybe_adjust_decimal_default(options), do: options

  @doc """
  Returns adjusted decimal value to options `precision` and `scale`.
  At this moment `precision` and `scale` are validated: `precision` > `scale` > 0.
  """
  def adjust_decimal_value(value, %{precision: precision} = options) do
    [whole_part, fractional_part] = String.split(value, ".")

    scale_default = [String.length(fractional_part), precision - 1] |> Enum.min()
    scale = Map.get(options, :scale, scale_default)
    fractional_part = fractional_part |> String.slice(0, scale) |> String.pad_trailing(scale, "0")

    whole_length = precision - scale
    whole_part = whole_part |> String.slice(-whole_length, whole_length)

    "#{whole_part}.#{fractional_part}"
  end

  def adjust_decimal_value(value, %{}), do: value

  defp derive_association_name(options, name) do
    association_name =
      options[:association_name] ||
        name |> Atom.to_string() |> String.replace("_id", "") |> String.to_atom()

    Map.put(options, :association_name, association_name)
  end

  defp derive_references_schema(options, name, {schema_module, context_base}) do
    full_referenced_schema =
      if referenced_schema = options[:referenced_schema] do
        [context_base, referenced_schema]
      else
        name = name |> Atom.to_string() |> String.replace("_id", "") |> Phoenix.Naming.camelize()
        (schema_module |> Module.split() |> Enum.drop(-1)) ++ [name]
      end

    Map.put(options, :referenced_schema, Module.concat(full_referenced_schema))
  end

  defp derive_references_table(options) do
    # NOTE: Option `table` is for cases when `referenced_schema` is not reachable.
    #       E.g. in generators' tests.
    table = options[:table] || options.referenced_schema.__schema__(:source)
    Map.put(options, :table, table)
  end

  defp derive_references_type(options) do
    column = options[:column] || :id
    # NOTE: Option `type` is for cases when `referenced_schema` is not reachable.
    #       E.g. in generators' tests.
    type = options[:type] || options.referenced_schema.__schema__(:type, column)
    Map.put(options, :type, type)
  end
end
