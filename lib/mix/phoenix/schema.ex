defmodule Mix.Phoenix.Schema do
  alias Mix.Phoenix.Schema

  defstruct module: nil,
            repo: nil,
            table: nil,
            opts: [],
            alias: nil,
            file: nil,
            attrs: [],
            string_attr: nil,
            plural: nil,
            singular: nil,
            uniques: [],
            assocs: [],
            types: [],
            indexes: [],
            defaults: [],
            human_singular: nil,
            human_plural: nil,
            binary_id: false,
            migration_defaults: nil,
            migration?: false,
            params: %{},
            sample_id: nil

  def valid?(schema) do
    schema =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/
  end

  def new(schema_name, schema_plural, cli_attrs, opts) do
    otp_app  = to_string(Mix.Phoenix.otp_app())
    basename = Phoenix.Naming.underscore(schema_name)
    module   = Module.concat([Mix.Phoenix.base(), schema_name])
    repo     = opts[:repo] || Module.concat([Mix.Phoenix.base(), "Repo"])
    file     = Path.join(["lib", otp_app, basename <> ".ex"])
    {assocs, cli_attrs} = partition_attrs_and_assocs(cli_attrs)
    attrs    = Mix.Phoenix.attrs(cli_attrs)
    uniques  = uniques(cli_attrs)
    table    = opts[:table] || schema_plural
    singular =
      module
      |> Module.split()
      |> List.last()
      |> Phoenix.Naming.underscore()
    string_attr =  attrs |> types() |> string_attr()
    create_params = Mix.Phoenix.params(attrs, :create)
    default_params_key =
      case Enum.at(create_params, 0) do
        {key, _} -> key
        nil -> :some_field
      end

    %Schema{
      opts: opts,
      migration?: opts[:migration] != false,
      module: module,
      repo: repo,
      table: table,
      alias: module |> Module.split() |> List.last() |> Module.concat(nil),
      file: file,
      attrs: attrs,
      plural: schema_plural,
      singular: singular,
      assocs: assocs,
      types: types(attrs),
      defaults: schema_defaults(attrs),
      uniques: uniques,
      indexes: indexes(table, assocs, uniques),
      human_singular: Phoenix.Naming.humanize(singular),
      human_plural: Phoenix.Naming.humanize(schema_plural),
      binary_id: opts[:binary_id],
      migration_defaults: migration_defaults(attrs),
      string_attr: string_attr,
      params: %{
        create: create_params,
        update: Mix.Phoenix.params(attrs, :update),
        default_key: string_attr || default_params_key
      },
      sample_id: sample_id(opts)}
  end

  @doc """
  Returns the string value of the default schema param.
  """
  def default_param(%Schema{} = schema, action) do
    schema.params
    |> Map.fetch!(action)
    |> Map.fetch!(schema.params.default_key)
    |> to_string()
  end

  @doc """
  Fetches the unique attributes from attrs.
  """
  def uniques(attrs) do
    attrs
    |> Enum.filter(&String.ends_with?(&1, ":unique"))
    |> Enum.map(& &1 |> String.split(":", parts: 2) |> hd |> String.to_atom)
  end

  defp partition_attrs_and_assocs(attrs) do
    {assocs, attrs} = Enum.partition(attrs, fn
      {_, {:references, _}} ->
        true
      {key, :references} ->
        Mix.raise """
        Phoenix generators expect the table to be given to #{key}:references.
        For example:

            mix phx.gen.schema Comment comments body:text post_id:references:posts
        """
      _ -> false
    end)

    assocs = Enum.map(assocs, fn {key_id, {:references, source}} ->
      key   = String.replace(Atom.to_string(key_id), "_id", "")
      assoc = Mix.Phoenix.inflect key
      {String.to_atom(key), key_id, assoc[:module], source}
    end)

    {assocs, attrs}
  end

  defp schema_defaults(attrs) do
    Enum.into(attrs, %{}, fn
      {key, :boolean}  -> {key, ", default: false"}
      {key, _}         -> {key, ""}
    end)
  end

  defp string_attr(types) do
    Enum.find_value(types, fn
      {key, {_col, :string}} -> key
      {key, :string} -> key
      _ -> false
    end)
  end

  defp types(attrs) do
    Enum.into(attrs, %{}, fn
      {key, {column, val}} -> {key, {column, value_to_type(val)}}
      {key, val}           -> {key, value_to_type(val)}
    end)
  end
  defp value_to_type(:text), do: :string
  defp value_to_type(:uuid), do: Ecto.UUID
  defp value_to_type(val) do
    if Code.ensure_loaded?(Ecto.Type) and not Ecto.Type.primitive?(val) do
      Mix.raise "Unknown type `#{val}` given to generator"
    else
      val
    end
  end

  defp indexes(table, assocs, uniques) do
    Enum.concat(
      Enum.map(uniques, fn key -> {key, true} end),
      Enum.map(assocs, fn {key, _} -> {key, false} end))
    |> Enum.uniq_by(fn {key, _} -> key end)
    |> Enum.map(fn
      {key, false} -> "create index(:#{table}, [:#{key}])"
      {key, true}  -> "create unique_index(:#{table}, [:#{key}])"
    end)
  end

  defp migration_defaults(attrs) do
    Enum.into(attrs, %{}, fn
      {key, :boolean}  -> {key, ", default: false, null: false"}
      {key, _}         -> {key, ""}
    end)
  end

  defp sample_id(opts) do
    if Keyword.get(opts, :binary_id, false) do
      Keyword.get(opts, :sample_binary_id, "11111111-1111-1111-1111-111111111111")
    else
      -1
    end
  end
end
