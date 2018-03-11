defmodule Mix.Tasks.Phx.New.Ecto do
  @moduledoc """
  Creates a new Ecto project within an umbrella project.

  This task is intended to create a bare Ecto project without
  web integration, which serves as a core application of your
  domain for web applications and your greater umbrella
  platform to integrate with.

  It expects the name of the project as an argument.

      $ cd my_umbrella/apps
      $ mix phx.new.ecto APP [--module MODULE] [--app APP]

  A project at the given APP directory will be created. The
  application name and module name will be retrieved
  from the application name, unless `--module` or `--app` is given.

  ## Options

    * `--app` - the name of the OTP application

    * `--module` - the name of the base module in
      the generated skeleton

    * `--database` - specify the database adapter for Ecto. One of:

        * `postgres` (https://github.com/elixir-ecto/postgrex)
        * `mysql` (https://github.com/xerions/mariaex)
        * `mssql` (https://github.com/findmypast-oss/mssqlex)

      Please check the driver docs, between parentheses, for more information
      and requirements. Defaults to "postgres".

    * `--binary-id` - use `binary_id` as primary key type
      in Ecto schemas

  ## Examples

      mix phx.new.ecto hello_ecto

  Is equivalent to:

      mix phx.new.ecto hello_ecto --module HelloEcto
  """

  @shortdoc "Creates a new Ecto project within an umbrella project"

  use Mix.Task
  import Phx.New.Generator

  def run([]) do
    Mix.Tasks.Help.run(["phx.new.ecto"])
  end
  def run([path | _] = args) do
    unless in_umbrella?(path) do
      Mix.raise "The ecto task can only be run within an umbrella's apps directory"
    end

    Mix.Tasks.Phx.New.run(args ++ ["--no-webpack", "--ecto"], Phx.New.Ecto)
  end
end
