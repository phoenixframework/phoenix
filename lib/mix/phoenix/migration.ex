defmodule Mix.Phoenix.Migration do
  @moduledoc false

  alias Mix.Phoenix.{Schema, Attribute}

  # THOUGHTS: Consider to make this module independent from schema.
  #           To reuse it for migration generator.
  #           Attributes parsing already extracted to reuse.

  @doc """
  Returns migration module based on the Mix application.
  """
  def module do
    case Application.get_env(:ecto_sql, :migration_module, Ecto.Migration) do
      migration_module when is_atom(migration_module) -> migration_module
      other -> Mix.raise("Expected :migration_module to be a module, got: #{inspect(other)}")
    end
  end

  @doc """
  Returns possible table options.
  """
  def table_options(%Schema{} = schema) do
    primary_key = if schema.binary_id || schema.opts[:primary_key], do: ", primary_key: false"
    prefix = if schema.prefix, do: ~s/, prefix: "#{schema.prefix}"/

    [primary_key, prefix] |> Enum.map_join(&(&1 || ""))
  end

  @doc """
  Returns specific primary key column by options `binary_id` or `primary_key`.
  """
  def maybe_specific_primary_key(%Schema{} = schema) do
    if schema.binary_id || schema.opts[:primary_key] do
      name = schema.opts[:primary_key] || :id
      type = if schema.binary_id, do: :binary_id, else: :id
      "      add :#{name}, :#{type}, primary_key: true\n"
    end
  end

  @doc """
  Returns formatted columns and references.
  """
  def columns_and_references(%Schema{} = schema) do
    schema.attrs
    |> Attribute.without_virtual()
    |> Attribute.sort()
    |> Enum.map(&"add :#{&1.name}, #{column_specifics(&1)}#{null_false(&1)}")
    |> Mix.Phoenix.indent_text(spaces: 6, bottom: 1)
  end

  defp null_false(%Attribute{} = attr), do: if(attr.options[:required], do: ", null: false")

  defp column_specifics(%Attribute{type: :references} = attr) do
    table = attr.options.referenced_table

    column =
      if attr.options.referenced_column != :id, do: ", column: :#{attr.options.referenced_column}"

    type = if attr.options.referenced_type != :id, do: ", type: :#{attr.options.referenced_type}"
    on_delete = ", on_delete: #{inspect(attr.options.on_delete)}"

    ~s/references("#{table}"#{column}#{type}#{on_delete})/
  end

  defp column_specifics(%Attribute{} = attr) do
    type = inspect(column_type(attr))
    precision_and_scale = column_precision_and_scale(attr)
    size = if attr.options[:size], do: ", size: #{attr.options.size}"
    default = if Map.has_key?(attr.options, :default), do: ", default: #{attr.options.default}"

    "#{type}#{precision_and_scale}#{size}#{default}"
  end

  defp column_type(%Attribute{type: {:array, type}} = attr),
    do: {:array, column_type(%{attr | type: type})}

  defp column_type(%Attribute{type: :enum, options: %{values: [value | _rest]}}),
    do: if(is_atom(value), do: :string, else: :integer)

  defp column_type(%Attribute{type: type}), do: type

  defp column_precision_and_scale(%Attribute{} = attr) do
    precision = attr.options[:precision]
    precision = if precision, do: ", precision: #{precision}", else: ""
    scale = attr.options[:scale]
    if scale, do: "#{precision}, scale: #{scale}", else: precision
  end

  @doc """
  Returns type option for `timestamps` function.
  """
  def timestamps_type(%Schema{timestamp_type: :naive_datetime}), do: ""
  def timestamps_type(%Schema{timestamp_type: timestamp_type}), do: "type: :#{timestamp_type}"

  @doc """
  Returns formatted indexes.
  """
  def indexes(%Schema{} = schema) do
    schema.attrs
    |> Attribute.indexed()
    |> Attribute.without_virtual()
    |> Attribute.sort()
    |> Enum.map(&index_specifics(&1, schema))
    |> Mix.Phoenix.indent_text(spaces: 4, top: 2)
  end

  defp index_specifics(attr, schema) do
    prefix = if schema.prefix, do: ~s/, prefix: "#{schema.prefix}"/
    unique = if attr.options[:unique], do: ", unique: true"

    ~s/create index("#{schema.table}", [:#{attr.name}]#{prefix}#{unique})/
  end
end
