defmodule Mix.Tasks.Phx.Gen.Embedded do
  @shortdoc "Generates an embedded Ecto schema file"

  @moduledoc """
  Generates an embedded Ecto schema for casting/validating data outside the DB.

      mix phx.gen.embedded Blog.Post blog_posts title:string views:integer

  The first argument is the schema module followed by its plural
  name (used as the table name).

  The generated schema above will contain:

    * an embedded schema file in lib/my_app/blog/post.ex.

  ## Attributes

  The resource fields are given using `name:type` syntax
  where type are the types supported by Ecto. Omitting
  the type makes it default to `:string`:

      mix phx.gen.embedded Blog.Post blog_posts title views:integer

  The following types are supported:

  #{for attr <- Mix.Phoenix.Schema.valid_types(), do: "  * `#{inspect attr}`\n"}
    * `:datetime` - An alias for `:naive_datetime`
  """
  use Mix.Task

  alias Mix.Tasks.Phx.Gen
  alias Mix.Phoenix.Schema

  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise "mix phx.gen.embedded can only be run inside an application directory"
    end

    schema = build(args, [])

    paths = Mix.Phoenix.generator_paths()

    prompt_for_conflicts(schema)

    copy_new_files(schema, paths, schema: schema)
  end

  def build(args, _opts), do: Gen.Schema.build(args, [embedded: true], Gen.Schema)

  defp prompt_for_conflicts(schema) do
    schema
    |> files_to_be_generated()
    |> Mix.Phoenix.prompt_for_conflicts()
  end

  def files_to_be_generated(%Schema{} = schema) do
    [{:eex, "embedded_schema.ex", schema.file}]
  end

  def copy_new_files(%Schema{} = schema, paths, binding) do
    files = files_to_be_generated(schema)
    Mix.Phoenix.copy_from(paths,"priv/templates/phx.gen.embedded", "", binding, files)

    schema
  end
end
