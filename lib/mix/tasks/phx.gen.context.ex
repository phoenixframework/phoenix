defmodule Mix.Tasks.Phx.Gen.Context do
  @shortdoc "Generates a context with functions around an Ecto schema"

  @moduledoc """
  Generates a context with functions around an Ecto schema.

      mix phx.gen.context Accounts User users name:string age:integer

  The first argument is the context name followed by the schema module
  and its plural name (used for resources and schema).

  The above generated resource will add the following files to lib/your_app:

    * a context module in accounts.ex, serving as the API boundary to the resource
    * a schema in accounts/user.ex, with an `accounts_users` table

  As well as a migration file for the repository and test files for
  generated context.

  ## Schema options

  By deault, the schema table name will be the plural name, namespaced by the
  context name. You can customize this value by providing the `--table`
  option to the generator.

  Read the documentation for `phx.gen.schema` for more information on
  attributes and supported options.
  """

  use Mix.Task

  alias Mix.Phoenix.{Context, Schema}
  alias Mix.Tasks.Phx.Gen

  def run(args) do
    if Mix.Project.umbrella? do
      Mix.raise "mix phx.gen.context can only be run inside an application directory"
    end

    {context, schema} = build(args)
    binding = [context: context, schema: schema]
    paths = Mix.Phoenix.generator_paths()

    context
    |> copy_new_files(paths, binding)
    |> print_shell_instructions()
  end

  def build(args) do
    switches = [binary_id: :boolean, table: :string]
    {opts, parsed, _} = OptionParser.parse(args, switches: switches)
    [context_name, schema_name, plural | schema_args] = validate_args!(parsed)

    table = Keyword.get(opts, :table, Phoenix.Naming.underscore(context_name) <> "_#{plural}")
    schema_module = inspect(Module.concat(context_name, schema_name))

    schema = Gen.Schema.build([schema_module, plural | schema_args] ++ ["--table", table], __MODULE__)
    context = Context.new(context_name, schema, opts)
    Mix.Phoenix.check_module_name_availability!(context.module)

    {context, schema}
  end

  def copy_new_files(%Context{schema: schema} = context, paths, binding) do
    Gen.Schema.copy_new_files(schema, paths, binding)
    inject_schema_access(context, paths, binding)
    Mix.Phoenix.copy_from paths, "priv/templates/phx.gen.context", "", binding, [
      {:new_eex, "context_test.exs", "test/#{context.basename}_test.exs"},
    ]
    context
  end

  defp inject_schema_access(%Context{dir: dir, file: file} = context, paths, binding) do
    unless context.pre_existing? do
      File.mkdir_p!(dir)
      File.write!(file, Mix.Phoenix.eval_from(paths, "priv/templates/phx.gen.context/context.ex", binding))
    end

    schema_content = Mix.Phoenix.eval_from(paths, "priv/templates/phx.gen.context/schema_access.ex", binding)

    file
    |> File.read!()
    |> String.trim_trailing()
    |> String.trim_trailing("end")
    |> EEx.eval_string(binding)
    |> Kernel.<>(schema_content)
    |> Kernel.<>("end\n")
    |> write_context(file)
  end

  defp write_context(content, file) do
    File.write!(file, content)
  end

  def print_shell_instructions(%Context{schema: schema}) do
    Gen.Schema.print_shell_instructions(schema)
  end

  defp validate_args!([context, schema, _plural | _] = args) do
    cond do
      not Context.valid?(context) ->
        raise_with_help "Expected the context, #{inspect context}, to be a valid module name"
      not Schema.valid?(schema) ->
        raise_with_help "Expected the schema, #{inspect schema}, to be a valid module name"
      context == schema ->
        raise_with_help "The context and schema should have different names"
      true ->
        args
    end
  end

  defp validate_args!(_) do
    raise_with_help "Invalid arguments"
  end

  @spec raise_with_help(String.t) :: no_return()
  def raise_with_help(msg) do
    Mix.raise """
    #{msg}

    mix phx.gen.html, phx.gen.json and phx.gen.context expect a
    context module name, followed by singular and plural names of
    the generated resource, ending with any number of attributes.
    For example:

        mix phx.gen.html Accounts User users name:string
        mix phx.gen.json Accounts User users name:string
        mix phx.gen.context Accounts User users name:string

    The context serves as the API boundary for the given resource.
    Multiple resources may belong to a context and a resource may be
    split over distinct contexts (such as Accounts.User and Blog.User).
    """
  end
end
