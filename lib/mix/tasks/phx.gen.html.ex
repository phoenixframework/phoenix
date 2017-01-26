defmodule Mix.Tasks.Phx.Gen.Html do
  use Mix.Task

  @shortdoc "TODO"

  @moduledoc """
  TODO
  """

  defmodule Context do
    defstruct module: nil,
              base_module: nil,
              web_module: nil,
              basename: nil,
              file: nil,
              dir: nil,
              opts: [],
              schema_module: nil,
              schema_alias: nil,
              schema_file: nil,
              schema_attrs: [],
              schema_plural: nil,
              schema_singular: nil,
              schema_uniques: [],
              schema_assocs: [],
              schema_types: [],
              schema_indexes: [],
              schema_defaults: [],
              pre_existing?: false

    @doc """
        iex> Context.new("Blog", "Post")
        %Context{module: "Blog",
                 base_module: "Phoenix",
                 module: "Phoenix.Blog",
                 basename: "blog",
                 file: "/path/to/phoenix/lib/blog.ex",
                 dir: "/path/to/phoenix/lib/blog",
                 schema_module: "Phoenix.Blog.Post",
                 schema_file: "/path/to/phoenix/blog/post.ex"}
    """
    def new(context_name, schema_name, schema_plural, attrs, opts) do
      base     = Module.concat([Mix.Phoenix.base()])
      module   = Module.concat(base, context_name)
      basename = Phoenix.Naming.underscore(context_name)
      dir      = Path.join(["lib", basename])
      file     = Path.join(["lib", basename <> ".ex"])
      schema_basename = Phoenix.Naming.underscore(schema_name)
      schema_module   = Module.concat(module, schema_name)
      schema_file     = Path.join([dir, schema_basename <> ".ex"])
      {assocs, attrs} = partition_attrs_and_assocs(attrs)
      schema_attrs    = Mix.Phoenix.attrs(attrs)
      uniques         = Mix.Phoenix.uniques(attrs)
      schema_singular =
        schema_module
        |> Module.split()
        |> List.last()
        |> Phoenix.Naming.underscore()

      %__MODULE__{module: module,
                  base_module: base,
                  web_module: Module.concat(base, "Web"),
                  basename: basename,
                  file: file,
                  dir: dir,
                  opts: opts,
                  schema_module: schema_module,
                  schema_alias: schema_module |> Module.split() |> List.last() |> Module.concat(nil),
                  schema_file: schema_file,
                  schema_attrs: schema_attrs,
                  schema_plural: schema_plural,
                  schema_singular: schema_singular,
                  schema_assocs: assocs,
                  schema_types: types(schema_attrs),
                  schema_defaults: schema_defaults(schema_attrs),
                  schema_uniques: uniques,
                  schema_indexes: indexes(schema_plural, assocs, uniques),
                  pre_existing?: File.exists?(file)}
    end

    def binding(%__MODULE__{} = context) do
      context
      |> Map.from_struct()
      |> Enum.into([
        human_singular: Phoenix.Naming.humanize(context.schema_singular),
        human_plural: Phoenix.Naming.humanize(context.schema_plural),
        binary_id: context.opts[:binary_id],
        migration_defaults: migration_defaults(context),
        inputs: inputs(context),
      ])
    end

    def inject_schema_access(%__MODULE__{} = context, paths, binding) do
      unless context.pre_existing? do
        File.write!(context.file, Mix.Phoenix.eval_from(paths, "priv/templates/phx.gen.html/context.ex", binding))
      end
      schema_content = Mix.Phoenix.eval_from(paths, "priv/templates/phx.gen.html/schema_access.ex", binding)

      context.file
      |> File.read!()
      |> String.trim_trailing()
      |> String.trim_trailing("end")
      |> EEx.eval_string(binding)
      |> Kernel.<>(schema_content)
      |> Kernel.<>("end\n")
      |> write_context(context)
    end
    defp write_context(content, context), do: File.write!(context.file, content)

    defp partition_attrs_and_assocs(attrs) do
      {assocs, attrs} = Enum.partition(attrs, fn
        {_, {:references, _}} ->
          true
        {key, :references} ->
          Mix.raise """
          Phoenix generators expect the table to be given to #{key}:references.
          For example:

              mix phoenix.gen.model Comment comments body:text post_id:references:posts
          """
        _ ->
          false
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

    defp indexes(plural, assocs, uniques) do
      Enum.concat(
        Enum.map(uniques, fn key -> {key, true} end),
        Enum.map(assocs, fn {key, _} -> {key, false} end))
        |> Enum.uniq_by(fn {key, _} -> key end)
        |> Enum.map(fn
        {key, false} -> "create index(:#{plural}, [:#{key}])"
        {key, true}  -> "create unique_index(:#{plural}, [:#{key}])"
      end)
    end

    defp migration_defaults(context) do
      Enum.into(context.schema_attrs, %{}, fn
        {key, :boolean}  -> {key, ", default: false, null: false"}
        {key, _}         -> {key, ""}
      end)
    end

    defp inputs(context) do
      Enum.map(context.schema_attrs, fn
        {_, {:array, _}} ->
          {nil, nil, nil}
        {_, {:references, _}} ->
          {nil, nil, nil}
        {key, :integer} ->
          {label(key), ~s(<%= number_input f, #{inspect(key)}, class: "form-control" %>), error(key)}
        {key, :float} ->
          {label(key), ~s(<%= number_input f, #{inspect(key)}, step: "any", class: "form-control" %>), error(key)}
        {key, :decimal} ->
          {label(key), ~s(<%= number_input f, #{inspect(key)}, step: "any", class: "form-control" %>), error(key)}
        {key, :boolean} ->
          {label(key), ~s(<%= checkbox f, #{inspect(key)}, class: "checkbox" %>), error(key)}
        {key, :text} ->
          {label(key), ~s(<%= textarea f, #{inspect(key)}, class: "form-control" %>), error(key)}
        {key, :date} ->
          {label(key), ~s(<%= date_select f, #{inspect(key)}, class: "form-control" %>), error(key)}
        {key, :time} ->
          {label(key), ~s(<%= time_select f, #{inspect(key)}, class: "form-control" %>), error(key)}
        {key, :utc_datetime} ->
          {label(key), ~s(<%= datetime_select f, #{inspect(key)}, class: "form-control" %>), error(key)}
        {key, :naive_datetime} ->
          {label(key), ~s(<%= datetime_select f, #{inspect(key)}, class: "form-control" %>), error(key)}
        {key, _}  ->
          {label(key), ~s(<%= text_input f, #{inspect(key)}, class: "form-control" %>), error(key)}
      end)
    end

    defp label(key) do
      ~s(<%= label f, #{inspect(key)}, class: "control-label" %>)
    end

    defp error(field) do
      ~s(<%= error_tag f, #{inspect(field)} %>)
    end
  end

  def run(args) do
    switches = [binary_id: :boolean, model: :boolean]
    {opts, parsed, _} = OptionParser.parse(args, switches: switches)
    [context, schema, plural | attrs] = validate_args!(parsed)

    context = Context.new(context, schema, plural, attrs, opts)
    binding = Context.binding(context)

    # TODO when I wake up:
    # - inject schema_access into context if pre-existing
    # - continue tests
    Context.inject_schema_access(context, paths(), binding)

    Mix.Phoenix.copy_from paths(), "priv/templates/phx.gen.html", "", binding, [
      {:eex, "schema.ex",          context.schema_file},
      {:eex, "controller.ex",      "lib/web/controllers/#{context.schema_singular}_controller.ex"},
      {:eex, "edit.html.eex",      "lib/web/templates/#{context.schema_singular}/edit.html.eex"},
      {:eex, "form.html.eex",      "lib/web/templates/#{context.schema_singular}/form.html.eex"},
      {:eex, "index.html.eex",     "lib/web/templates/#{context.schema_singular}/index.html.eex"},
      {:eex, "new.html.eex",       "lib/web/templates/#{context.schema_singular}/new.html.eex"},
      {:eex, "show.html.eex",      "lib/web/templates/#{context.schema_singular}/show.html.eex"},
      {:eex, "view.ex",            "lib/web/views/#{context.schema_singular}_view.ex"},
      {:eex, "migration.exs",      "priv/repo/migrations/#{timestamp()}_create_#{String.replace(context.schema_singular, "/", "_")}.exs"},

      # {:eex, "controller_test.exs", "test/web/controllers/#{context.schema_singular}_controller_test.exs"},
    ]

    # IO.puts EEx.eval_file("priv/templates/phx.gen.html/context.ex", binding)
    # IO.puts EEx.eval_file("priv/templates/phx.gen.html/schema_access.ex", binding)
    # IO.puts EEx.eval_file("priv/templates/phx.gen.html/controller.ex", binding)
    # IO.puts EEx.eval_file("priv/templates/phx.gen.html/migration.ex", binding)
    # IO.puts EEx.eval_file("priv/templates/phx.gen.html/view.ex", binding)
    # IO.puts EEx.eval_file("priv/templates/phx.gen.html/schema.ex", binding)
    # for view <- ~w(edit form index new show) do
    #   IO.puts EEx.eval_file("priv/templates/phx.gen.html/#{view}.html.eex", binding)
    # end
    # Context.inject_schema_access(context, binding)
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: << ?0, ?0 + i >>
  defp pad(i), do: to_string(i)

  defp paths do
    [".", :phoenix]
  end

  defp validate_args!([_, _, plural | _] = args) do
    cond do
      String.contains?(plural, ":") ->
        raise_with_help()
      plural != Phoenix.Naming.underscore(plural) ->
        Mix.raise "Expected the third argument, #{inspect plural}, to be all lowercase using snake_case convention"
      true ->
        args
    end
  end

  defp validate_args!(_) do
    raise_with_help()
  end

  @spec raise_with_help() :: no_return()
  defp raise_with_help do
    Mix.raise """
    mix phoenix.gen.html expects both singular and plural names
    of the generated resource followed by any number of attributes:

        mix phoenix.gen.html User users name:string
    """
  end
end
