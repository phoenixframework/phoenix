defmodule Mix.Phoenix.Schema do
  @moduledoc false

  alias Mix.Phoenix.Schema

  defstruct module: nil,
            repo: nil,
            table: nil,
            embedded?: false,
            generate?: true,
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
            sample_id: nil,
            web_path: nil,
            web_namespace: nil,
            context_app: nil,
            route_helper: nil

  @valid_types [:integer, :float, :decimal, :boolean, :map, :string,
                :array, :references, :text, :date, :time,
                :naive_datetime, :utc_datetime, :uuid, :binary]

  def valid_types, do: @valid_types

  def valid?(schema) do
    schema =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/
  end

  def new(schema_name, schema_plural, cli_attrs, opts) do
    ctx_app   = opts[:context_app] || Mix.Phoenix.context_app()
    otp_app   = Mix.Phoenix.otp_app()
    opts      = Keyword.merge(Application.get_env(otp_app, :generators, []), opts)
    base      = Mix.Phoenix.context_base(ctx_app)
    basename  = Phoenix.Naming.underscore(schema_name)
    module    = Module.concat([base, schema_name])
    repo      = opts[:repo] || Module.concat([base, "Repo"])
    file      = Mix.Phoenix.context_lib_path(ctx_app, basename <> ".ex")
    table     = opts[:table] || schema_plural
    uniques   = uniques(cli_attrs)
    {assocs, attrs} = partition_attrs_and_assocs(module, attrs(cli_attrs))
    types = types(attrs)
    web_namespace = opts[:web]
    web_path = web_namespace && Phoenix.Naming.underscore(web_namespace)
    embedded? = Keyword.get(opts, :embedded, false)
    generate? = Keyword.get(opts, :schema, true)

    singular =
      module
      |> Module.split()
      |> List.last()
      |> Phoenix.Naming.underscore()
    string_attr = string_attr(types)
    create_params = params(attrs, :create)
    default_params_key =
      case Enum.at(create_params, 0) do
        {key, _} -> key
        nil -> :some_field
      end
    route_helper = if web_path, do: "#{web_path}_#{singular}", else: singular

    %Schema{
      opts: opts,
      migration?: Keyword.get(opts, :migration, true),
      module: module,
      repo: repo,
      table: table,
      embedded?: embedded?,
      alias: module |> Module.split() |> List.last() |> Module.concat(nil),
      file: file,
      attrs: attrs,
      plural: schema_plural,
      singular: singular,
      assocs: assocs,
      types: types,
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
        update: params(attrs, :update),
        default_key: string_attr || default_params_key
      },
      web_namespace: web_namespace,
      web_path: web_path,
      route_helper: route_helper,
      sample_id: sample_id(opts),
      context_app: ctx_app,
      generate?: generate?}
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

  @doc """
  Parses the attrs as received by generators.
  """
  def attrs(attrs) do
    Enum.map(attrs, fn attr ->
      attr
      |> drop_unique()
      |> String.split(":", parts: 3)
      |> list_to_attr()
      |> validate_attr!()
    end)
  end

  @doc """
  Generates some sample params based on the parsed attributes.
  """
  def params(attrs, action \\ :create) when action in [:create, :update] do
    attrs
    |> Enum.reject(fn
        {_, {:references, _}} -> true
        {_, _} -> false
       end)
    |> Enum.into(%{}, fn {k, t} -> {k, type_to_default(k, t, action)} end)
  end

  @doc """
  Returns the string value for use in EEx templates.
  """
  def value(schema, field, value) do
    schema.types
    |> Map.fetch!(field)
    |> inspect_value(value)
  end
  defp inspect_value(:decimal, value), do: "Decimal.new(\"#{value}\")"
  defp inspect_value(:utc_datetime, value), do: "DateTime.from_naive!(~N[#{value}], \"Etc/UTC\")"
  defp inspect_value(_type, value), do: inspect(value)

  defp drop_unique(info) do
    prefix = byte_size(info) - 7
    case info do
      <<attr::size(prefix)-binary, ":unique">> -> attr
      _ -> info
    end
  end

  defp list_to_attr([key]), do: {String.to_atom(key), :string}
  defp list_to_attr([key, value]), do: {String.to_atom(key), String.to_atom(value)}
  defp list_to_attr([key, comp, value]) do
    {String.to_atom(key), {String.to_atom(comp), String.to_atom(value)}}
  end

  defp type_to_default(key, t, :create) do
    case t do
        {:array, _}     -> []
        :integer        -> 42
        :float          -> 120.5
        :decimal        -> "120.5"
        :boolean        -> true
        :map            -> %{}
        :text           -> "some #{key}"
        :date           -> %Date{year: 2010, month: 4, day: 17}
        :time           -> %Time{hour: 14, minute: 0, second: 0, microsecond: {0, 6}}
        :uuid           -> "7488a646-e31f-11e4-aace-600308960662"
        :utc_datetime   -> "2010-04-17 14:00:00.000000Z"
        :naive_datetime -> ~N[2010-04-17 14:00:00.000000]
        _               -> "some #{key}"
    end
  end
  defp type_to_default(key, t, :update) do
    case t do
        {:array, _}     -> []
        :integer        -> 43
        :float          -> 456.7
        :decimal        -> "456.7"
        :boolean        -> false
        :map            -> %{}
        :text           -> "some updated #{key}"
        :date           -> %Date{year: 2011, month: 5, day: 18}
        :time           -> %Time{hour: 15, minute: 1, second: 1, microsecond: {0, 6}}
        :uuid           -> "7488a646-e31f-11e4-aace-600308960668"
        :utc_datetime   -> "2011-05-18 15:01:01.000000Z"
        :naive_datetime -> ~N[2011-05-18 15:01:01.000000]
        _               -> "some updated #{key}"
    end
  end

  defp validate_attr!({name, :datetime}), do: validate_attr!({name, :naive_datetime})
  defp validate_attr!({name, :array}) do
    Mix.raise """
    Phoenix generators expect the type of the array to be given to #{name}:array.
    For example:

        mix phx.gen.schema Post posts settings:array:string
    """
  end
  defp validate_attr!({_name, type} = attr) when type in @valid_types, do: attr
  defp validate_attr!({_name, {type, _}} = attr) when type in @valid_types, do: attr
  defp validate_attr!({_, type}) do
    Mix.raise "Unknown type `#{inspect type}` given to generator. " <>
              "The supported types are: #{@valid_types |> Enum.sort() |> Enum.join(", ")}"
  end

  defp partition_attrs_and_assocs(schema_module, attrs) do
    {assocs, attrs} =
      Enum.partition(attrs, fn
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

    assocs =
      Enum.map(assocs, fn {key_id, {:references, source}} ->
        key = String.replace(Atom.to_string(key_id), "_id", "")
        base = schema_module |> Module.split() |> Enum.drop(-1)
        module = Module.concat(base ++ [Phoenix.Naming.camelize(key)])
        {String.to_atom(key), key_id, inspect(module), source}
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
      {key, {root, val}} -> {key, {root, schema_type(val)}}
      {key, val} -> {key, schema_type(val)}
    end)
  end

  defp schema_type(:text), do: :string
  defp schema_type(:uuid), do: Ecto.UUID
  defp schema_type(val) do
    if Code.ensure_loaded?(Ecto.Type) and not Ecto.Type.primitive?(val) do
      Mix.raise "Unknown type `#{val}` given to generator"
    else
      val
    end
  end

  defp indexes(table, assocs, uniques) do
    uniques = Enum.map(uniques, fn key -> {key, true} end)
    assocs = Enum.map(assocs, fn {_, key, _, _} -> {key, false} end)

    (uniques ++ assocs)
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
