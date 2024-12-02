defmodule Mix.Tasks.Phx.Gen.Schema do
  @shortdoc "Generates an Ecto schema and migration file"

  @moduledoc """
  Generates an Ecto schema and migration.

      $ mix phx.gen.schema Blog.Post blog_posts title:string views:integer

  The first argument is the schema module followed by its plural
  name (used as the table name).

  The generated schema above will contain:

    * a schema file in `lib/my_app/blog/post.ex`, with a `blog_posts` table
    * a migration file for the repository

  The generated migration can be skipped with `--no-migration`.

  ## Contexts

  Your schemas can be generated and added to a separate OTP app.
  Make sure your configuration is properly setup or manually
  specify the context app with the `--context-app` option with
  the CLI.

  Via config:

      config :marketing_web, :generators, context_app: :marketing

  Via CLI:

      $ mix phx.gen.schema Blog.Post blog_posts title:string views:integer --context-app marketing

  ## Attributes

  The resource fields are given using `name:type:options` syntax
  where type are the types supported by Ecto. Default type is `string`,
  which can be omitted when field doesn't have options.

      $ mix phx.gen.schema Blog.Post blog_posts title slug:string:unique views:integer

  The generator also supports references. The given column name we will
  properly associate to the primary key column of the referenced table.
  Be default all info is going to be inferred from column name via
  referenced schema search in the same context.

      $ mix phx.gen.schema Blog.Post blog_posts title user_id:references

  We can provide specifics via options. E.g. if we associate with schema
  in different context we can specify options for full schema name
  (schema naming has the same approach as schema we are creating).

      $ mix phx.gen.schema Blog.Post blog_posts title user_id:references:Accounts.User

  This will result in a migration with column `:user_id` properly set
  with referenced table and type, and create an index.
  See other options below.

  An array type can also be given if it is supported by your database.
  By default type of underlying array element is `string`.
  You can provide specific type:

      $ mix phx.gen.schema Blog.Post blog_posts tags:array
      $ mix phx.gen.schema Blog.Post blog_posts tags:[array,integer]

  Unique columns can be automatically generated with option `unique`.

      $ mix phx.gen.schema Blog.Post blog_posts title:string:unique unique_int:integer:unique

  Redact columns can be automatically generated with option `redact`.

      $ mix phx.gen.schema Accounts.Superhero superheroes secret_identity:string:redact password:string:redact

  Ecto.Enum fields can be generated with mandatory list of values in
  options. At least one value should be provided.

      $ mix phx.gen.schema Blog.Post blog_posts title status:enum:[unpublished,published,deleted]

  #{Mix.Phoenix.Attribute.supported_types()}

  #{Mix.Phoenix.Attribute.supported_options()}

  ## table

  By default, the table name for the migration and schema will be
  the plural name provided for the resource. To customize this value,
  a `--table` option may be provided. For example:

      $ mix phx.gen.schema Blog.Post posts --table cms_posts

  ## binary_id

  Generated migration can use `binary_id` for schema's primary key
  with option `--binary-id`.

      $ mix phx.gen.schema Blog.Post posts title --binary-id

  ## primary_key

  By default, the primary key in the table is called `id`. This option
  allows to change the name of the primary key column. For example:

      $ mix phx.gen.schema Blog.post posts --primary-key post_id

  ## repo

  Generated migration can use `repo` to set the migration repository
  folder with option `--repo`:

      $ mix phx.gen.schema Blog.Post posts --repo MyApp.Repo.Auth

  ## migration_dir

  Generated migrations can be added to a specific `--migration-dir` which sets
  the migration folder path:

      $ mix phx.gen.schema Blog.Post posts --migration-dir /path/to/directory


  ## prefix

  By default migrations and schemas are generated without a prefix.

  For PostgreSQL this sets the "SCHEMA" (typically set via `search_path`)
  and for MySQL it sets the database for the generated migration and schema.
  The prefix can be used to thematically organize your tables on the database level.

  A prefix can be specified with the `--prefix` flags. For example:

      $ mix phx.gen.schema Blog.Post posts --prefix blog

  > #### Warning {: .warning}
  >
  > The flag does not generate migrations to create the schema / database.
  > This needs to be done manually or in a separate migration.

  ## Default options

  This generator uses default options provided in the `:generators`
  configuration of your application. These are the defaults:

      config :your_app, :generators,
        migration: true,
        timestamp_type: :naive_datetime,
        binary_id: false,
        sample_binary_id: "11111111-1111-1111-1111-111111111111"

  You can override those options per invocation by providing corresponding
  switches, e.g. `--no-binary-id` to use normal ids despite the default
  configuration or `--migration` to force generation of the migration.

  ## UTC timestamps

  By setting the `:timestamp_type` to `:utc_datetime`, the timestamps
  will be created using the UTC timezone. This results in a `DateTime` struct
  instead of a `NaiveDateTime`. This can also be set to `:utc_datetime_usec` for
  microsecond precision.

  """
  use Mix.Task
  # TODO: shpakvel, update this doc.

  alias Mix.Phoenix.Schema

  @switches [
    migration: :boolean,
    binary_id: :boolean,
    table: :string,
    web: :string,
    context_app: :string,
    prefix: :string,
    repo: :string,
    migration_dir: :string,
    compile: :boolean,
    primary_key: :string
  ]

  @doc false
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix phx.gen.schema must be invoked from within your *_web application root directory"
      )
    end

    schema = build(args, [])
    paths = Mix.Phoenix.generator_paths()

    prompt_for_conflicts(schema)

    schema
    |> copy_new_files(paths, schema: schema)
    |> print_shell_instructions()
  end

  defp prompt_for_conflicts(schema) do
    schema
    |> files_to_be_generated()
    |> Mix.Phoenix.prompt_for_conflicts()
  end

  @doc false
  def build(args, parent_opts, help \\ __MODULE__) do
    {schema_opts, parsed, _} = OptionParser.parse(args, switches: @switches)
    [schema_name, plural | attrs] = validate_args!(parsed, help)

    if Mix.env() != :test or "--compile" in args do
      # NOTE: It is needed to get loaded Ecto.Schema for using reflection.
      Mix.Task.run("compile")
      validate_required_dependencies!()
    end

    opts =
      parent_opts
      |> Keyword.merge(schema_opts)
      |> put_context_app(schema_opts[:context_app])
      |> maybe_update_repo_module()

    Schema.new(schema_name, plural, attrs, opts)
  end

  defp validate_required_dependencies! do
    if not Code.ensure_loaded?(Ecto.Schema), do: Mix.raise("mix phx.gen.schema requires ecto")
  end

  defp maybe_update_repo_module(opts) do
    if is_nil(opts[:repo]) do
      opts
    else
      Keyword.update!(opts, :repo, &Module.concat([&1]))
    end
  end

  defp put_context_app(opts, nil), do: opts

  defp put_context_app(opts, string) do
    Keyword.put(opts, :context_app, String.to_atom(string))
  end

  @doc false
  def files_to_be_generated(%Schema{} = schema) do
    [{:eex, "schema.ex", schema.file}]
  end

  @doc false
  def copy_new_files(
        %Schema{context_app: ctx_app, repo: repo, opts: opts} = schema,
        paths,
        binding
      ) do
    files = files_to_be_generated(schema)
    Mix.Phoenix.copy_from(paths, "priv/templates/phx.gen.schema", binding, files)

    if schema.migration? do
      migration_dir =
        cond do
          migration_dir = opts[:migration_dir] ->
            migration_dir

          opts[:repo] ->
            repo_name = repo |> Module.split() |> List.last() |> Macro.underscore()
            Mix.Phoenix.context_app_path(ctx_app, "priv/#{repo_name}/migrations/")

          true ->
            Mix.Phoenix.context_app_path(ctx_app, "priv/repo/migrations/")
        end

      migration_path = Path.join(migration_dir, "#{timestamp()}_create_#{schema.table}.exs")

      Mix.Phoenix.copy_from(paths, "priv/templates/phx.gen.schema", binding, [
        {:eex, "migration.exs", migration_path}
      ])
    end

    schema
  end

  @doc false
  def print_shell_instructions(%Schema{} = schema) do
    if schema.migration? do
      Mix.shell().info("""

      Remember to update your repository by running migrations:

          $ mix ecto.migrate
      """)
    end
  end

  @doc false
  def validate_args!([schema, plural | _] = args, help) do
    cond do
      not Schema.valid?(schema) ->
        help.raise_with_help("Expected the schema, #{inspect(schema)}, to be a valid module name")

      String.contains?(plural, ":") or plural != Phoenix.Naming.underscore(plural) ->
        help.raise_with_help(
          "Expected the plural argument, #{inspect(plural)}, to be all lowercase using snake_case convention"
        )

      true ->
        args
    end
  end

  def validate_args!(_, help) do
    help.raise_with_help("Invalid arguments")
  end

  @doc false
  @spec raise_with_help(String.t()) :: no_return()
  def raise_with_help(msg) do
    Mix.raise("""
    #{msg}

    mix phx.gen.schema expects both a module name and
    the plural of the generated resource followed by
    any number of attributes:

        mix phx.gen.schema Blog.Post blog_posts title:string
    """)
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)
end
