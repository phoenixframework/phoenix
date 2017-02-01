defmodule Mix.Tasks.Phx.Gen.Schema do
  use Mix.Task

  alias Mix.Phoenix.Schema

  @shortdoc "TODO"

  @moduledoc """
  TODO
  """

  @switches [migration: :boolean, binary_id: :boolean]

  def run(args) do
    schema = build(args)
    paths = Mix.Phoenix.generator_paths()

    schema
    |> copy_new_files(paths, schema: schema)
    |> print_shell_instructions()
  end

  def build(args) do
    {opts, parsed, _} = OptionParser.parse(args, switches: @switches)
    [schema_name, plural | attrs] = validate_args!(parsed)

    schema = Schema.new(schema_name, plural, attrs, opts)
    Mix.Phoenix.check_module_name_availability!(schema.module)

    schema
  end

  def copy_new_files(%Schema{} = schema, paths, binding) do
    Mix.Phoenix.copy_from paths, "priv/templates/phx.gen.html", "", binding, [
      {:eex, "schema.ex",          schema.file},
      {:eex, "migration.exs",      "priv/repo/migrations/#{timestamp()}_create_#{String.replace(schema.singular, "/", "_")}.exs"},
    ]
    schema
  end

  def print_shell_instructions(%Schema{} = schema) do
    if schema.migration? do
      Mix.shell.info """

      Remember to update your repository by running migrations:

          $ mix ecto.migrate
      """
    end
  end

  defp validate_args!([_, plural | _] = args) do
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
    mix phx.gen.schema expects both singular and plural names
    of the generated resource followed by any number of attributes:

        mix phoenix.gen.schema Accounts.User users name:string
    """
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end
  defp pad(i) when i < 10, do: << ?0, ?0 + i >>
  defp pad(i), do: to_string(i)
end
