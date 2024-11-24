defmodule Mix.Tasks.Phx.Gen.Embedded do
  @shortdoc "Generates an embedded Ecto schema file"

  @moduledoc """
  Generates an embedded Ecto schema for casting/validating data outside the DB.

      mix phx.gen.embedded Blog.Post title:string views:integer

  The first argument is the schema module followed by the schema attributes.

  The generated schema above will contain:

    * an embedded schema file in `lib/my_app/blog/post.ex`

  ## Attributes

  The resource fields are given using `name:type:options` syntax
  where type are the types supported by Ecto. Default type is `string`,
  which can be omitted when field doesn't have options.

      mix phx.gen.embedded Blog.Post title views:integer

  #{Mix.Phoenix.Attribute.supported_types()}

  #{Mix.Phoenix.Attribute.supported_options()}
  """
  use Mix.Task

  alias Mix.Phoenix.Schema

  @switches [web: :string]

  @doc false
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix phx.gen.embedded must be invoked from within your *_web application root directory"
      )
    end

    schema = build(args)

    paths = Mix.Phoenix.generator_paths()

    prompt_for_conflicts(schema)

    copy_new_files(schema, paths, schema: schema)
  end

  @doc false
  def build(args) do
    {schema_opts, parsed, _} = OptionParser.parse(args, switches: @switches)
    [schema_name | attrs] = validate_args!(parsed)

    opts =
      schema_opts
      |> Keyword.put(:embedded, true)
      |> Keyword.put(:migration, false)

    Schema.new(schema_name, nil, attrs, opts)
  end

  @doc false
  def validate_args!([schema | _] = args) do
    if Schema.valid?(schema) do
      args
    else
      raise_with_help("Expected the schema, #{inspect(schema)}, to be a valid module name")
    end
  end

  def validate_args!(_) do
    raise_with_help("Invalid arguments")
  end

  @doc false
  @spec raise_with_help(String.t()) :: no_return()
  def raise_with_help(msg) do
    Mix.raise("""
    #{msg}

    mix phx.gen.embedded expects a module name followed by
    any number of attributes:

        mix phx.gen.embedded Blog.Post title:string
    """)
  end

  defp prompt_for_conflicts(schema) do
    schema
    |> files_to_be_generated()
    |> Mix.Phoenix.prompt_for_conflicts()
  end

  @doc false
  def files_to_be_generated(%Schema{} = schema) do
    [{:eex, "embedded_schema.ex", schema.file}]
  end

  @doc false
  def copy_new_files(%Schema{} = schema, paths, binding) do
    files = files_to_be_generated(schema)
    Mix.Phoenix.copy_from(paths, "priv/templates/phx.gen.embedded", binding, files)

    schema
  end
end
