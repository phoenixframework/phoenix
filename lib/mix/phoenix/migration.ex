defmodule Mix.Phoenix.Migration do
  @moduledoc false

  alias Mix.Phoenix.{Schema, Attribute}

  # THOUGHTS: Consider to make this module independent from schema.
  #           To reuse it for migration generator.
  #           Attributes parsing already extracted to reuse.

  @doc """
  Returns migration module to use in migration.
  """
  def module do
    case Application.get_env(:ecto_sql, :migration_module, Ecto.Migration) do
      migration_module when is_atom(migration_module) -> migration_module
      other -> Mix.raise("Expected :migration_module to be a module, got: #{inspect(other)}")
    end
  end

  @doc """
  Returns formatted columns and references to list in migration.
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
    table = attr.options.table
    column = if attr.options[:column], do: ", column: :#{attr.options.column}"
    type = if attr.options.type != :id, do: ", type: :#{attr.options.type}"
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

  defp column_type(%Attribute{type: {:array, inner_type}} = attr),
    do: {:array, column_type(%{attr | type: inner_type})}

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
  Returns formatted indexes to list in migration.
  """
  def indexes(%Schema{} = schema) do
    schema.attrs
    |> Attribute.indexed()
    |> Attribute.without_virtual()
    |> Attribute.sort()
    |> Enum.map(&~s/create index("#{schema.table}", #{index_specifics(&1)})/)
    |> Mix.Phoenix.indent_text(spaces: 4, top: 2)
  end

  defp index_specifics(attr) do
    unique = if attr.options[:unique], do: ", unique: true"

    "[:#{attr.name}]#{unique}"
  end
end
