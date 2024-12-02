defmodule Mix.Phoenix.Schema do
  @moduledoc false

  alias Mix.Phoenix.{Schema, Attribute, TestData}

  defstruct module: nil,
            alias: nil,
            repo: nil,
            repo_alias: nil,
            table: nil,
            file: nil,
            singular: nil,
            plural: nil,
            collection: nil,
            human_singular: nil,
            human_plural: nil,
            binary_id: false,
            sample_id: nil,
            timestamp_type: :naive_datetime,
            web_namespace: nil,
            web_path: nil,
            route_helper: nil,
            route_prefix: nil,
            api_route_prefix: nil,
            context_app: nil,
            prefix: nil,
            embedded?: false,
            generate?: true,
            migration?: false,
            opts: [],
            attrs: [],
            sample_values: %{}

  @doc """
  Validates format of schema name.
  """
  def valid?(schema) do
    schema =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/
  end

  def new(schema_name, schema_plural, cli_attrs, opts) do
    ctx_app = opts[:context_app] || Mix.Phoenix.context_app()
    otp_app = Mix.Phoenix.otp_app()
    opts = Keyword.merge(Application.get_env(otp_app, :generators, []), opts)
    context_base = Mix.Phoenix.context_base(ctx_app)
    module = Module.concat([context_base, schema_name])
    alias = module |> Module.split() |> List.last() |> Module.concat(nil)
    repo = opts[:repo] || Module.concat([context_base, "Repo"])
    repo_alias = if String.ends_with?(Atom.to_string(repo), ".Repo"), do: "", else: ", as: Repo"
    basename = Phoenix.Naming.underscore(schema_name)
    file = Mix.Phoenix.context_lib_path(ctx_app, basename <> ".ex")
    table = opts[:table] || schema_plural
    singular = module |> Module.split() |> List.last() |> Phoenix.Naming.underscore()
    collection = if schema_plural == singular, do: singular <> "_collection", else: schema_plural
    web_namespace = opts[:web] && Phoenix.Naming.camelize(opts[:web])
    web_path = web_namespace && Phoenix.Naming.underscore(web_namespace)
    api_prefix = Application.get_env(otp_app, :generators)[:api_prefix] || "/api"

    embedded? = Keyword.get(opts, :embedded, false)
    generate? = Keyword.get(opts, :schema, true)
    migration? = Keyword.get(opts, :migration, true)

    attrs = Attribute.parse(cli_attrs, {module, context_base})
    sample_values = TestData.sample_values(attrs, module)

    %Schema{
      module: module,
      alias: alias,
      repo: repo,
      repo_alias: repo_alias,
      table: table,
      file: file,
      singular: singular,
      plural: schema_plural,
      collection: collection,
      human_singular: Phoenix.Naming.humanize(singular),
      human_plural: Phoenix.Naming.humanize(schema_plural),
      binary_id: opts[:binary_id],
      sample_id: sample_id(opts),
      timestamp_type: opts[:timestamp_type] || :naive_datetime,
      web_namespace: web_namespace,
      web_path: web_path,
      route_helper: route_helper(web_path, singular),
      route_prefix: route_prefix(web_path, schema_plural),
      api_route_prefix: api_route_prefix(web_path, schema_plural, api_prefix),
      context_app: ctx_app,
      prefix: opts[:prefix],
      embedded?: embedded?,
      generate?: generate?,
      migration?: migration?,
      opts: opts,
      attrs: attrs,
      sample_values: sample_values
    }
  end

  # TODO: Check for clean up.
  #       Looks like anachronism, which wasn't used until only `phx.gen.auth` start to use it.
  defp sample_id(opts) do
    if Keyword.get(opts, :binary_id, false) do
      Keyword.get(opts, :sample_binary_id, "11111111-1111-1111-1111-111111111111")
    else
      -1
    end
  end

  defp route_helper(web_path, singular) do
    "#{web_path}_#{singular}"
    |> String.trim_leading("_")
    |> String.replace("/", "_")
  end

  defp route_prefix(web_path, plural) do
    path = Path.join(for str <- [web_path, plural], do: to_string(str))
    "/" <> String.trim_leading(path, "/")
  end

  defp api_route_prefix(web_path, plural, api_prefix) do
    path = Path.join(for str <- [api_prefix, web_path, plural], do: to_string(str))
    "/" <> String.trim_leading(path, "/")
  end

  @doc """
  Returns module attributes.
  """
  def module_attributes(%Schema{} = schema) do
    schema_prefix = if schema.prefix, do: "\n@schema_prefix :#{schema.prefix}"

    derive =
      if schema.opts[:primary_key],
        do: "\n@derive {Phoenix.Param, key: :#{schema.opts[:primary_key]}}"

    primary_key =
      if schema.binary_id || schema.opts[:primary_key] do
        name = schema.opts[:primary_key] || :id
        type = if schema.binary_id, do: :binary_id, else: :id
        "\n@primary_key {:#{name}, :#{type}, autogenerate: true}"
      end

    [schema_prefix, derive, primary_key]
    |> Enum.map_join(&(&1 || ""))
    |> Mix.Phoenix.indent_text(spaces: 2, top: 1)
  end

  @doc """
  Returns formatted fields and associations.
  """
  def fields_and_associations(%Schema{} = schema) do
    schema.attrs
    |> Attribute.sort()
    |> Enum.map(&field_specifics/1)
    |> Mix.Phoenix.indent_text(spaces: 4, top: 1, bottom: 1)
  end

  defp field_specifics(%Attribute{type: :references} = attr) do
    association_name = attr.options.association_name
    association_schema = inspect(attr.options.association_schema)
    foreign_key = if :"#{association_name}_id" != attr.name, do: ", foreign_key: :#{attr.name}"

    references =
      if attr.options.referenced_column != :id,
        do: ", references: :#{attr.options.referenced_column}"

    type = if attr.options.referenced_type != :id, do: ", type: :#{attr.options.referenced_type}"

    "belongs_to :#{association_name}, #{association_schema}#{foreign_key}#{references}#{type}"
  end

  defp field_specifics(%Attribute{} = attr) do
    name = inspect(attr.name)
    type = inspect(field_type(attr))
    values = enum_values_option(attr)

    default =
      if Map.has_key?(attr.options, :default),
        do: ", default: #{field_value(attr.options.default, attr)}"

    redact = if attr.options[:redact], do: ", redact: true"
    virtual = if attr.options[:virtual], do: ", virtual: true"

    "field #{name}, #{type}#{values}#{default}#{redact}#{virtual}"
  end

  defp field_type(%Attribute{type: {:array, inner_type}} = attr),
    do: {:array, field_type(%{attr | type: inner_type})}

  defp field_type(%Attribute{type: :text}), do: :string
  defp field_type(%Attribute{type: :uuid}), do: Ecto.UUID
  defp field_type(%Attribute{type: :enum}), do: Ecto.Enum
  defp field_type(%Attribute{type: type}), do: type

  defp enum_values_option(%Attribute{type: :enum} = attr),
    do: ", values: #{inspect(attr.options.values)}"

  defp enum_values_option(%Attribute{type: {:array, inner_type}} = attr),
    do: enum_values_option(%{attr | type: inner_type})

  defp enum_values_option(_attr), do: ""

  def field_value(value, %Attribute{type: :decimal}), do: "Decimal.new(\"#{value}\")"
  def field_value(value, %Attribute{}), do: inspect(value)

  @doc """
  Returns type option for `timestamps` function.
  """
  def timestamps_type(%Schema{timestamp_type: :naive_datetime}), do: ""
  def timestamps_type(%Schema{timestamp_type: timestamp_type}), do: "type: :#{timestamp_type}"

  @doc """
  Returns formatted fields to cast.
  """
  def cast_fields(%Schema{} = schema) do
    schema.attrs
    |> Attribute.sort()
    |> Enum.map_join(", ", &inspect(&1.name))
  end

  @doc """
  Returns formatted fields to require.
  """
  def required_fields(%Schema{} = schema) do
    schema.attrs
    |> Attribute.required()
    |> Attribute.sort()
    |> Enum.map_join(", ", &inspect(&1.name))
  end

  @doc """
  Returns specific changeset constraints.
  """
  def changeset_constraints(%Schema{} = schema) do
    length_validations(schema) <>
      assoc_constraints(schema) <>
      unique_constraints(schema)
  end

  @doc """
  Returns length validations.
  """
  def length_validations(%Schema{} = schema) do
    schema.attrs
    |> Enum.filter(& &1.options[:size])
    |> Attribute.sort()
    |> Enum.map(&"|> validate_length(:#{&1.name}, max: #{&1.options[:size]})")
    |> Mix.Phoenix.indent_text(spaces: 4, top: 1)
  end

  @doc """
  Returns association constraints.
  """
  def assoc_constraints(%Schema{} = schema) do
    schema.attrs
    |> Attribute.references()
    |> Enum.sort_by(& &1.options.association_name)
    |> Enum.map(&"|> assoc_constraint(:#{&1.options.association_name})")
    |> Mix.Phoenix.indent_text(spaces: 4, top: 1)
  end

  @doc """
  Returns unique constraints.
  """
  def unique_constraints(%Schema{} = schema) do
    schema.attrs
    |> Attribute.unique()
    |> Attribute.without_virtual()
    |> Attribute.sort()
    |> Enum.map(&"|> unique_constraint(:#{&1.name})")
    |> Mix.Phoenix.indent_text(spaces: 4, top: 1)
  end
end
