defmodule Mix.Tasks.Phoenix.Des.Model do
  use Mix.Task

  @shortdoc "Destroys an Ecto model"

  @moduledoc """
  Destroys an Ecto model in your Phoenix application.

      mix phoenix.des.model User

  or

      mix phoenix.des.model User users

  The first argument is the module name (optionally followed by its plural
  name).

  The destroyed model files include:

    * a model in web/models
    * a migration file for the repository  (note: this task does not rollback the migration)

  Destroying the migration can be skipped with `--no-migration`.

  ## Namespaced resources

  Resources can be namespaced, for such, it is just necessary
  to namespace the first argument of the task:

      mix phoenix.des.model Admin.User users

  ## Default options

  This task uses default options provided in the `:generators` configuration
  of the `:phoenix` application. You can override those options providing
  corresponding switches, e.g. `--no-migration` to force removal of the migration.

  """
  def run(args) do
    switches = [migration: :boolean, binary_id: :boolean, instructions: :string]

    {opts, parsed, _} = OptionParser.parse(args, switches: switches)
    [singular | _] = validate_args!(parsed)

    default_opts = Application.get_env(:phoenix, :generators, [])
    opts = Keyword.merge(default_opts, opts)

    binding   = Mix.Phoenix.inflect(singular)
    path      = binding[:path]

    files = files(path, opts[:migration])
    Mix.shell.info("""

      WARNING: mix phoenix.des.model will DELETE the following files:

    """)

    Enum.each(files, fn(x) -> Mix.shell.info(x) end)
    Mix.shell.info " "

    if Mix.shell.yes?("Are you sure you want these files destroyed?") do
      Enum.each(files, fn(x) -> File.rm!(x) end)
      Mix.shell.info "Files successfully removed."
    else
      Mix.shell.info "Operation canceled, no files removed."
    end
  end

  def files(path, remove_migration) do
    migration = String.replace(path, "/", "_")
    files = [
      "web/models/#{path}.ex",
      "test/models/#{path}_test.exs"
    ]

    if remove_migration != false do
      files =
        List.flatten(Path.wildcard("priv/repo/migrations/*_create_#{migration}.exs"), files)
    end
    files
  end

  defp validate_args!([_, plural | _] = args) do
    cond do
      String.contains?(plural, ":") ->
        raise_with_help
      plural != Phoenix.Naming.underscore(plural) ->
        Mix.raise "expected the second argument, #{inspect plural}, to be all lowercase using snake_case convention"
      true ->
        args
    end
  end
  defp validate_args!(args), do: args

  defp raise_with_help do
    Mix.raise """
    mix phoenix.des.model expects the singular name
    of the resource:

        mix phoenix.des.model User

    or the singular and plural names of the resource:

        mix phoenix.des.model User users
    """
  end
end
